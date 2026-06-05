#!/usr/bin/env python3
"""
Spill token metering adapter for Claude Code.

Reads the Stop hook payload from stdin, extracts the last turn's token
usage from the Claude Code transcript, and enqueues one JSON event file
in the Spill local queue.

Install: add to ~/.claude/settings.json (or .claude/settings.json) Stop hooks:
  {
    "type": "command",
    "command": "python3 /path/to/spill-hook.py",
    "timeout": 5
  }
"""
import datetime
import json
import os
import pathlib
import re
import sys
import uuid

INBOX_DIR = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_INBOX_DIR",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/events-inbox",
    )
)
LABEL_FILE = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_LABEL_FILE",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/label-context/claude.json",
    )
)
_OPAQUE_ID = re.compile(r'^[A-Za-z0-9_-]{6,64}$')
_MODEL_ID = re.compile(r'^[A-Za-z0-9_.:-]{2,80}$')
_SAFE_SLUG = re.compile(r'^[a-z][a-z0-9_]{1,40}$')

# Tools that produce code/config changes.
_WRITE_TOOLS = {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}
# Tools that read without changing state.
_READ_TOOLS = {'Read', 'Grep', 'WebFetch', 'WebSearch', 'LS'}


def _opaque(value: str, fallback: str) -> str:
    return value if _OPAQUE_ID.match(value) else fallback


def _payload_value(payload: dict, *keys: str) -> str:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, str):
            return value

    for container_key in ("spill", "spill_metering", "spillMetering"):
        nested = payload.get(container_key)
        if not isinstance(nested, dict):
            continue
        for key in keys:
            value = nested.get(key)
            if isinstance(value, str):
                return value

    return ""


def _safe_label(payload: dict, keys: tuple[str, ...], env_keys: tuple[str, ...], fallback: str) -> str:
    payload_label = _payload_value(payload, *keys)
    if _SAFE_SLUG.match(payload_label):
        return payload_label

    for env_key in env_keys:
        env_label = os.environ.get(env_key, "")
        if _SAFE_SLUG.match(env_label):
            return env_label

    file_label = _label_file_value(*keys)
    if _SAFE_SLUG.match(file_label):
        return file_label

    return fallback


def _label_file_value(*keys: str) -> str:
    try:
        data = json.loads(LABEL_FILE.read_text())
    except Exception:
        return ""

    if not isinstance(data, dict):
        return ""

    tool = data.get("ai_tool", "")
    if tool not in ("", "unknown", "claude"):
        return ""

    expires_at = data.get("expires_at", "")
    if isinstance(expires_at, str) and expires_at:
        try:
            expiry = datetime.datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
            if datetime.datetime.now(datetime.timezone.utc) > expiry:
                return ""
        except Exception:
            return ""

    for key in keys:
        value = data.get(key)
        if isinstance(value, str):
            return value
    return ""


def _enqueue_event(event: dict) -> None:
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    event_id = uuid.uuid4().hex
    temporary_path = INBOX_DIR / f".{event_id}.tmp"
    final_path = INBOX_DIR / f"{event_id}.json"

    with open(temporary_path, "x") as f:
        f.write(json.dumps(event, separators=(",", ":")))
    os.chmod(temporary_path, 0o600)
    os.replace(temporary_path, final_path)


def _infer_task_type(tool_names: set) -> str:
    """Infer task_type from tool call names only — no content inspection."""
    if tool_names & _WRITE_TOOLS:
        return 'code_generation'
    if tool_names and not (tool_names - _READ_TOOLS - {'Bash'}):
        return 'analysis'
    if not tool_names:
        return 'analysis'
    return 'uncategorized'


def _infer_stage(tool_names: set) -> str:
    """Infer stage from tool call names only — no content inspection."""
    if tool_names & _WRITE_TOOLS:
        return 'implement'
    if 'Bash' in tool_names and not (tool_names & _WRITE_TOOLS):
        return 'verify'
    return 'summarize'


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return

    transcript_path = payload.get("transcript_path", "")
    session_id = payload.get("session_id", "")

    if not transcript_path or not pathlib.Path(transcript_path).is_file():
        return

    # Collect all assistant messages in the last turn (reset on each user message).
    turns: list[dict] = []
    try:
        with open(transcript_path) as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    obj = json.loads(raw)
                    msg = obj.get("message", {})
                    role = msg.get("role", "")
                    if role in {"human", "user"}:
                        turns = []
                    elif role == "assistant" and "usage" in msg:
                        turns.append(msg)
                except Exception:
                    pass
    except Exception:
        return

    if not turns:
        return

    # Collect tool names used in this turn (name field only, not inputs).
    tool_names: set[str] = set()
    for turn in turns:
        for item in turn.get("content", []):
            if isinstance(item, dict) and item.get("type") == "tool_use":
                name = item.get("name", "")
                if name:
                    tool_names.add(name)

    cache_read = sum(t["usage"].get("cache_read_input_tokens", 0) for t in turns)
    fresh = sum(
        t["usage"].get("input_tokens", 0) + t["usage"].get("cache_creation_input_tokens", 0)
        for t in turns
    )
    output = sum(t["usage"].get("output_tokens", 0) for t in turns)
    total = cache_read + fresh + output

    if total == 0:
        return

    raw_model = turns[-1].get("model", "")
    model = raw_model if _MODEL_ID.match(raw_model) else "claude-unknown"

    run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])
    span_id = "span-" + uuid.uuid4().hex[:12]
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
    inferred_task_type = _infer_task_type(tool_names)
    inferred_stage = _infer_stage(tool_names)
    task_type = _safe_label(
        payload,
        ("task_type", "taskType"),
        ("SPILL_TOKEN_USAGE_TASK_TYPE", "SPILL_WORKFLOW_TASK_TYPE"),
        inferred_task_type,
    )
    stage = _safe_label(
        payload,
        ("stage", "workflow_stage", "workflowStage"),
        ("SPILL_TOKEN_USAGE_STAGE", "SPILL_WORKFLOW_STAGE"),
        inferred_stage,
    )

    event = {
        "schema_version": 1,
        "device_id": "device_local",
        "project_id": "project_global",
        "artifact_id": "artifact_global",
        "run_id": run_id,
        "span_id": span_id,
        "ai_tool": "claude",
        "task_type": task_type,
        "stage": stage,
        "model": model,
        "input_tokens": cache_read + fresh,
        "output_tokens": output,
        "total_tokens": total,
        "token_breakdown": {
            "system": 0,
            "user": 0,
            "history": cache_read,
            "repo_context": 0,
            "tool_output": 0,
            "generated_output": output,
            "unknown": fresh,
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
