#!/usr/bin/env python3
"""
Spill token metering adapter for OpenAI API / SDK.

Wraps the OpenAI Python SDK. Import and use `SpillOpenAIClient` in place
of `openai.OpenAI`. Each completed response is recorded to the Spill
local queue.

Usage:
  from spill_adapter import SpillOpenAIClient
  client = SpillOpenAIClient()  # reads OPENAI_API_KEY from env
  response = client.chat.completions.create(
      model="gpt-4o",
      messages=[{"role": "user", "content": "Hello"}]
  )

Requires: pip install openai
"""
import datetime
import json
import os
import pathlib
import re
import uuid

INBOX_DIR = pathlib.Path.home() / "Library/Application Support/Spill/token-metering/events-inbox"
_MODEL_ID = re.compile(r'^[A-Za-z0-9_.:-]{2,80}$')


def _enqueue_event(event: dict) -> None:
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    event_id = uuid.uuid4().hex
    temporary_path = INBOX_DIR / f".{event_id}.tmp"
    final_path = INBOX_DIR / f"{event_id}.json"

    with open(temporary_path, "x") as f:
        f.write(json.dumps(event, separators=(",", ":")))
    os.chmod(temporary_path, 0o600)
    os.replace(temporary_path, final_path)


def _append_event(model: str, input_tokens: int, output_tokens: int, run_id: str) -> None:
    total = input_tokens + output_tokens
    if total == 0:
        return

    safe_model = model if _MODEL_ID.match(model) else "openai-unknown"
    span_id = "span-" + uuid.uuid4().hex[:12]
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

    event = {
        "schema_version": 1,
        "device_id": "device_local",
        "project_id": "project_global",
        "artifact_id": "artifact_global",
        "run_id": run_id,
        "span_id": span_id,
        "ai_tool": "openai",
        "task_type": "uncategorized",
        "stage": "summarize",
        "model": safe_model,
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


class _SpillCompletions:
    def __init__(self, inner, run_id: str):
        self._inner = inner
        self._run_id = run_id

    def create(self, model: str, **kwargs):
        response = self._inner.create(model=model, **kwargs)
        try:
            usage = response.usage
            if usage:
                _append_event(
                    model=model,
                    input_tokens=int(getattr(usage, "prompt_tokens", 0)),
                    output_tokens=int(getattr(usage, "completion_tokens", 0)),
                    run_id=self._run_id,
                )
        except Exception:
            pass
        return response


class _SpillChat:
    def __init__(self, inner, run_id: str):
        self.completions = _SpillCompletions(inner.completions, run_id)


class SpillOpenAIClient:
    """Drop-in wrapper for openai.OpenAI that records token usage to Spill."""

    def __init__(self, **kwargs):
        try:
            import openai
            self._client = openai.OpenAI(**kwargs)
        except ImportError:
            raise RuntimeError("openai package is required: pip install openai")

        self._run_id = "run-" + uuid.uuid4().hex[:12]
        self.chat = _SpillChat(self._client.chat, self._run_id)

    def __getattr__(self, name):
        return getattr(self._client, name)
