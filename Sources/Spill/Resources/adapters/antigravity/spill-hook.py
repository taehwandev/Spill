#!/usr/bin/env python3
"""
Spill token metering adapter for Antigravity (AGY).

Reads the AGY PostInvocation or Stop hook payload from stdin, extracts exact
token usage from the hook payload, and enqueues one JSON event file in the
Spill local queue.

Install: configure AGY to call this script as a PostInvocation or Stop hook in ~/.gemini/config/hooks.json.
"""
import datetime
import json
import os
import pathlib
import re
import sys
import uuid

INBOX_DIR = pathlib.Path.home() / "Library/Application Support/Spill/token-metering/events-inbox"
_OPAQUE_ID = re.compile(r'^[A-Za-z0-9_-]{6,64}$')
_MODEL_ID = re.compile(r'^[A-Za-z0-9_.:-]{2,80}$')
_SAFE_SLUG = re.compile(r'^[a-z][a-z0-9_]{1,40}$')


def _opaque(value: str, fallback: str) -> str:
    return value if _OPAQUE_ID.match(value) else fallback


def _safe_slug(value: str, fallback: str) -> str:
    return value if _SAFE_SLUG.match(value) else fallback


def _enqueue_event(event: dict) -> None:
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    event_id = uuid.uuid4().hex
    temporary_path = INBOX_DIR / f".{event_id}.tmp"
    final_path = INBOX_DIR / f"{event_id}.json"

    with open(temporary_path, "x") as f:
        f.write(json.dumps(event, separators=(",", ":")))
    os.chmod(temporary_path, 0o600)
    os.replace(temporary_path, final_path)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return

    # Extract tokens from standard fields
    usage = payload.get("usage", {})
    input_tokens = int(payload.get("input_tokens", usage.get("input_tokens", usage.get("prompt_tokens", 0))))
    output_tokens = int(payload.get("output_tokens", usage.get("output_tokens", usage.get("completion_tokens", 0))))
    
    # Try alternate fields in case they are structured differently
    if input_tokens == 0 and output_tokens == 0:
        tokens_obj = payload.get("tokens", {})
        input_tokens = int(tokens_obj.get("input", tokens_obj.get("prompt", 0)))
        output_tokens = int(tokens_obj.get("output", tokens_obj.get("completion", 0)))

    total = input_tokens + output_tokens

    if total == 0:
        return

    raw_model = payload.get("model", "")
    model = raw_model if _MODEL_ID.match(raw_model) else "antigravity-unknown"

    session_id = str(payload.get("session_id", payload.get("conversationId", "")))
    run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])
    span_id = "span-" + uuid.uuid4().hex[:12]
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

    task_type = _safe_slug(str(payload.get("task_type", payload.get("taskType", ""))), "uncategorized")
    stage = _safe_slug(str(payload.get("stage", "")), "summarize")

    event = {
        "schema_version": 1,
        "device_id": "device_local",
        "project_id": "project_global",
        "artifact_id": "artifact_global",
        "run_id": run_id,
        "span_id": span_id,
        "ai_tool": "antigravity",
        "task_type": task_type,
        "stage": stage,
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "total_tokens": total,
        "token_breakdown": {
            "system": 0,
            "user": 0,
            "history": 0,
            "repo_context": 0,
            "tool_output": 0,
            "generated_output": output_tokens,
            "unknown": input_tokens,
        },
        "latency_ms": 0,
        "created_at": now,
        "sync_mode": "local_only",
    }

    _enqueue_event(event)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
