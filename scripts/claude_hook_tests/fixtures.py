#!/usr/bin/env python3
"""Isolated safe synthetic metadata and queue assertions for Claude hook tests.

No real Claude transcripts, Spill stores, labels, or diagnostics are read. Both
the canonical adapter and its bundled copy run the same regression suite.
--negative-control accepts an earlier adapter copy to reproduce the old bugs;
those expected failures are evidence for the regression fixtures, not gates.
--benchmark optionally compares that copy against the canonical adapter using
identical fixtures. Timings measure local instrumented processing, not tokens
or billed API cost. There are deliberately no timing assertions in the tests.
"""

import contextlib
import datetime
import hashlib
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).resolve().parents[2]
ADAPTERS = (
    ROOT / "adapters/claude-code/spill-hook.py",
    ROOT / "Sources/Spill/Resources/adapters/claude-code/spill-hook.py",
)
SESSION = "00000000-0000-4000-8000-000000000001"
MODEL = "claude-synthetic"
TIMESTAMP = "2026-01-01T00:25:00Z"
EVENT_KEYS = {
    "schema_version", "device_id", "project_id", "artifact_id", "run_id",
    "span_id", "ai_tool", "task_type", "stage", "model", "input_tokens",
    "output_tokens", "total_tokens", "token_breakdown", "latency_ms", "created_at",
}
BREAKDOWN_KEYS = {
    "system", "user", "history", "repo_context", "tool_output",
    "generated_output", "unknown",
}
ACCOUNTING_KEYS = {
    "uncached_input_tokens", "cache_creation_input_tokens",
    "cache_read_input_tokens", "reasoning_output_tokens",
}
LABEL_ENV = {
    key: "" for key in (
        "SPILL_TOKEN_USAGE_TASK_TYPE", "SPILL_WORKFLOW_TASK_TYPE",
        "SPILL_TOKEN_USAGE_STAGE", "SPILL_WORKFLOW_STAGE",
        "SPILL_TOKEN_USAGE_PROJECT_ID", "SPILL_PROJECT_ID",
    )
}
LABEL_ENV["SPILL_TOKEN_USAGE_DISABLE_DIAGNOSTICS"] = "1"


def record(index=0, request_id=True, timestamp=TIMESTAMP):
    value = {
        "timestamp": timestamp,
        "message": {
            "role": "assistant",
            "model": MODEL,
            "usage": {
                "input_tokens": 7,
                "cache_creation_input_tokens": 11,
                "cache_read_input_tokens": 13,
                "output_tokens": 17,
            },
        },
    }
    if request_id:
        value["requestId"] = f"opaque-request-{index:06d}"
    return value


def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def label(updated, expires, task="debugging", stage="implement", **extra):
    value = {
        "ai_tool": "claude", "task_type": task, "stage": stage,
        "project_id": "project_global", "updated_at": updated, "expires_at": expires,
    }
    value.update(extra)
    return value


def at(minute, second=0):
    return f"2026-01-01T00:{minute:02d}:{second:02d}Z"


class Fixture:
    def __init__(self, adapter):
        self.adapter = adapter
        self.temporary = tempfile.TemporaryDirectory(prefix="spill-hook-fixture-")
        self.root = pathlib.Path(self.temporary.name)
        spec = importlib.util.spec_from_file_location("spill_synthetic_hook", adapter)
        self.hook = importlib.util.module_from_spec(spec)
        # Unit loading must not create bytecode inside packaged adapter resources.
        with mock.patch.object(sys, "dont_write_bytecode", True):
            spec.loader.exec_module(self.hook)
        # Redirect every app-owned location before any event/state function runs.
        self.hook.INBOX_DIR = self.root / "inbox"
        self.hook.SESSION_STATE_DIR = self.root / "state"
        self.hook.LABEL_FILE = self.root / "labels.json"
        self.hook.LABEL_TIMELINE_FILE = self.root / "labels-timeline.jsonl"
        self.hook.DIAGNOSTICS_DIR = self.root / "diagnostics"
        self.hook._USED_LABEL_FILE = False
        self.source = self.root / f"{SESSION}.jsonl"
        self.events = []
        self.hook._enqueue_event = self.capture
        self.hook._enqueue_events = self.capture_batch
        self.environment = mock.patch.dict(os.environ, LABEL_ENV)
        self.environment.start()

    def close(self):
        self.environment.stop()
        self.temporary.cleanup()

    def capture(self, event, accounting=None):
        self.events.append((dict(event), dict(accounting or {})))

    def capture_batch(self, records):
        for item in records:
            self.capture(item.get("event", item), item.get("accounting"))

    def write(self, rows, source=None, final_newline=True):
        source = source or self.source
        source.parent.mkdir(parents=True, exist_ok=True)
        raw = b"\n".join(encoded(row) for row in rows)
        source.write_bytes(raw + (b"\n" if final_newline else b""))
        return source

    def append(self, data):
        with self.source.open("ab") as stream:
            stream.write(data)

    def payload(self):
        return {"transcript_path": str(self.source), "session_id": SESSION}

    def live(self, scan_subagents=False):
        return self.hook._run_for_payload(
            self.payload(), scan_subagents=scan_subagents, allow_timestamp_fallback=False,
        )

    def history(self):
        return self.hook._run_history_payload(self.payload(), enqueue_event=self.capture)

    def cli(self):
        # A minimal child environment redirects every app-owned path before import.
        environment = {
            **LABEL_ENV,
            "SPILL_TOKEN_USAGE_INBOX_DIR": str(self.hook.INBOX_DIR),
            "SPILL_TOKEN_USAGE_SESSION_STATE_DIR": str(self.hook.SESSION_STATE_DIR),
            "SPILL_TOKEN_USAGE_LABEL_FILE": str(self.hook.LABEL_FILE),
            "SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR": str(self.hook.DIAGNOSTICS_DIR),
        }
        return subprocess.run(
            [sys.executable, "-B", str(self.adapter)], input=json.dumps(self.payload()),
            text=True, capture_output=True, env=environment, cwd=self.root, timeout=10,
        )

    def timeline(self, rows):
        self.hook.LABEL_TIMELINE_FILE.write_text(
            "\n".join(json.dumps(row, separators=(",", ":")) for row in rows) + "\n",
        )

    def state(self):
        return json.loads((self.hook.SESSION_STATE_DIR / f"{SESSION}.json").read_text())


@contextlib.contextmanager
def count_reads(fixture):
    counts = {"timeline_reads": 0, "json_loads": 0}
    original_open = pathlib.Path.open
    original_loads = json.loads

    def open_file(path, *args, **kwargs):
        if path == fixture.hook.LABEL_TIMELINE_FILE:
            counts["timeline_reads"] += 1
        return original_open(path, *args, **kwargs)

    def loads(*args, **kwargs):
        counts["json_loads"] += 1
        return original_loads(*args, **kwargs)

    with mock.patch.object(pathlib.Path, "open", open_file), mock.patch.object(json, "loads", loads):
        yield counts


class HookRegressionCase(unittest.TestCase):
    adapter = None

    def setUp(self):
        self.fixture = Fixture(self.adapter)
        self.addCleanup(self.fixture.close)
        self.f = self.fixture

    def assert_event(self, pair, index=0, run_id=SESSION):
        event, accounting = pair
        self.assertEqual(set(event), EVENT_KEYS)
        self.assertEqual(set(event["token_breakdown"]), BREAKDOWN_KEYS)
        self.assertEqual(set(accounting), ACCOUNTING_KEYS)
        self.assertEqual((event["input_tokens"], event["output_tokens"], event["total_tokens"]), (31, 17, 48))
        self.assertEqual(event["token_breakdown"]["unknown"], 31)
        self.assertEqual(event["token_breakdown"]["generated_output"], 17)
        self.assertEqual(sum(event["token_breakdown"].values()), 48)
        self.assertEqual(accounting, {
            "uncached_input_tokens": 7, "cache_creation_input_tokens": 11,
            "cache_read_input_tokens": 13, "reasoning_output_tokens": 0,
        })
        self.assertEqual(event["run_id"], run_id)
        self.assertEqual(event["model"], MODEL)
        source = f"{run_id}:{MODEL}:opaque-request-{index:06d}:18:17"
        self.assertEqual(event["span_id"], "span-" + hashlib.sha256(source.encode()).hexdigest()[:12])

    def run_real_cli(self):
        result = self.f.cli()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def queued_records(self):
        rows = []
        inbox = self.f.hook.INBOX_DIR
        for path in sorted(inbox.glob("*")):
            if path.suffix not in {".json", ".jsonl"}:
                continue
            raw = path.read_text()
            events = [json.loads(raw)] if path.suffix == ".json" else [json.loads(line) for line in raw.splitlines()]
            sidecar = path.with_suffix(".accounting")
            accounts = [json.loads(line) for line in sidecar.read_text().splitlines()]
            self.assertEqual(len(accounts), len(events))
            by_span = {value["span_id"]: value for value in accounts}
            self.assertEqual(len(by_span), len(accounts))
            self.assertEqual(path.stat().st_mode & 0o077, 0)
            self.assertEqual(sidecar.stat().st_mode & 0o077, 0)
            for event in events:
                account = by_span[event["span_id"]]
                self.assertEqual(set(account), ACCOUNTING_KEYS | {"schema_version", "span_id", "ai_tool"})
                self.assertEqual((account["schema_version"], account["ai_tool"]), (1, "claude"))
                self.assertEqual(set(event), EVENT_KEYS)
                rows.append((path.suffix, event, {key: account[key] for key in ACCOUNTING_KEYS}))
        self.assertEqual(list(inbox.glob("*.tmp")), [])
        self.assertEqual(len({event["span_id"] for _, event, _ in rows}), len(rows))
        return rows
