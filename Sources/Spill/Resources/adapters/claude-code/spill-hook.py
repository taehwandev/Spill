#!/usr/bin/env python3
"""
Spill token metering adapter for Claude Code.

Reads the Stop hook payload from stdin, extracts all turns' token usage
from the Claude Code transcript, and enqueues one JSON event file in the
Spill local queue.

Token counting: sums input_tokens + cache_creation_input_tokens + output_tokens
across all turns. cache_read_input_tokens is excluded — it is the accumulated
cached context re-read each turn and would massively overcount if included.

Install: add to ~/.claude/settings.json (or .claude/settings.json) Stop hooks:
  {
    "type": "command",
    "command": "python3 /path/to/spill-hook.py",
    "timeout": 5
  }
"""
import datetime
import hashlib
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
SESSION_STATE_DIR = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_SESSION_STATE_DIR",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/session-state",
    )
)
LABEL_FILE = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_LABEL_FILE",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/label-context/claude.json",
    )
)
DIAGNOSTICS_DIR = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/diagnostics",
    )
)
EMPTY_DIAGNOSTIC_FILE_NAME = "claude-last-empty.json"
MISMATCH_DIAGNOSTIC_FILE_NAME = "claude-last-mismatch.json"
SUCCESS_DIAGNOSTIC_FILE_NAME = "claude-last-success.json"
_OPAQUE_ID = re.compile(r'^[A-Za-z0-9_-]{6,64}$')
_MODEL_ID = re.compile(r'^[A-Za-z0-9_.:-]{2,80}$')
_SAFE_SLUG = re.compile(r'^[a-z][a-z0-9_]{1,40}$')

# Tools that produce code/config changes.
_WRITE_TOOLS = {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}
# Tools that read without changing state.
_READ_TOOLS = {'Read', 'Grep', 'WebFetch', 'WebSearch', 'LS'}
_USED_LABEL_FILE = False


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
    global _USED_LABEL_FILE
    payload_label = _payload_value(payload, *keys)
    if _SAFE_SLUG.match(payload_label):
        return payload_label

    for env_key in env_keys:
        env_label = os.environ.get(env_key, "")
        if _SAFE_SLUG.match(env_label):
            return env_label

    file_label = _label_file_value(*keys)
    if _SAFE_SLUG.match(file_label):
        _USED_LABEL_FILE = True
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


def _diagnostic_timestamp() -> str:
    return datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")


def _safe_payload_shape(payload: dict = None) -> dict:
    if not isinstance(payload, dict):
        return {
            "payload_object": False,
            "has_transcript_path": False,
            "has_session_id": False,
            "has_safe_label_hint": False,
        }

    return {
        "payload_object": True,
        "has_transcript_path": isinstance(payload.get("transcript_path"), str)
        and bool(payload.get("transcript_path")),
        "has_session_id": isinstance(payload.get("session_id"), str)
        and bool(payload.get("session_id")),
        "has_safe_label_hint": any(
            isinstance(payload.get(key), str) and _SAFE_SLUG.match(payload.get(key))
            for key in ("task_type", "taskType", "stage", "workflow_stage", "workflowStage")
        ),
    }


def _write_diagnostic_file(filename: str, kind: str, reason: str, payload: dict = None, meaning: str = "") -> None:
    if os.environ.get("SPILL_TOKEN_USAGE_DISABLE_DIAGNOSTICS") == "1":
        return

    diagnostic = {
        "schema_version": 1,
        "ai_tool": "claude",
        "kind": kind,
        "reason": reason,
        "created_at": _diagnostic_timestamp(),
        "expected_input_contracts": [
            "claude_stop_hook_transcript_path",
            "claude_stop_hook_session_id",
        ],
        "observed_safe_shape": _safe_payload_shape(payload),
        "privacy": "No payload values, prompts, commands, file paths, logs, diffs, transcript content, source, environment values, or secrets are stored.",
    }
    if meaning:
        diagnostic["meaning"] = meaning

    try:
        DIAGNOSTICS_DIR.mkdir(parents=True, exist_ok=True)
        final_path = DIAGNOSTICS_DIR / filename
        temporary_path = DIAGNOSTICS_DIR / f".{filename}.tmp"
        with open(temporary_path, "w") as f:
            f.write(json.dumps(diagnostic, separators=(",", ":")))
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, final_path)
    except Exception:
        pass


def _write_success_diagnostic(event: dict) -> None:
    if os.environ.get("SPILL_TOKEN_USAGE_DISABLE_DIAGNOSTICS") == "1":
        return

    diagnostic = {
        "schema_version": 1,
        "ai_tool": "claude",
        "kind": "success",
        "reason": "usage_event_enqueued",
        "created_at": _diagnostic_timestamp(),
        "event_created_at": event["created_at"],
        "task_type": event["task_type"],
        "stage": event["stage"],
        "model": event["model"],
        "input_tokens": event["input_tokens"],
        "output_tokens": event["output_tokens"],
        "total_tokens": event["total_tokens"],
        "privacy": "No prompts, commands, file paths, logs, diffs, transcript content, source, environment values, secrets, run ids, or span ids are stored.",
    }

    try:
        DIAGNOSTICS_DIR.mkdir(parents=True, exist_ok=True)
        final_path = DIAGNOSTICS_DIR / SUCCESS_DIAGNOSTIC_FILE_NAME
        temporary_path = DIAGNOSTICS_DIR / f".{SUCCESS_DIAGNOSTIC_FILE_NAME}.tmp"
        with open(temporary_path, "w") as f:
            f.write(json.dumps(diagnostic, separators=(",", ":")))
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, final_path)
        _clear_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME)
    except Exception:
        pass


def _clear_diagnostic_file(filename: str) -> None:
    try:
        (DIAGNOSTICS_DIR / filename).unlink()
    except Exception:
        pass


def _stable_span_id(*parts: str) -> str:
    source = ":".join(parts)
    return "span-" + hashlib.sha256(source.encode("utf-8")).hexdigest()[:12]


def _load_session_state(run_id: str) -> tuple[int, int]:
    """Return (prev_fresh, prev_output) recorded for this run, or (0, 0)."""
    state_path = SESSION_STATE_DIR / f"{run_id}.json"
    try:
        data = json.loads(state_path.read_text())
        if isinstance(data, dict):
            return int(data.get("fresh", 0)), int(data.get("output", 0))
    except Exception:
        pass
    return 0, 0


def _save_session_state(run_id: str, fresh: int, output: int) -> None:
    try:
        SESSION_STATE_DIR.mkdir(parents=True, exist_ok=True)
        state_path = SESSION_STATE_DIR / f"{run_id}.json"
        tmp_path = SESSION_STATE_DIR / f".{run_id}.tmp"
        tmp_path.write_text(json.dumps({"fresh": fresh, "output": output}))
        os.replace(tmp_path, state_path)
    except Exception:
        pass


def _consume_label_file() -> None:
    if not _USED_LABEL_FILE:
        return
    try:
        LABEL_FILE.unlink()
    except Exception:
        pass


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
        raw_payload = sys.stdin.read()
    except Exception:
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "stdin_unavailable")
        return

    if not raw_payload.strip():
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "empty_stdin_hook_call",
            "empty_stdin",
            meaning="Claude Code invoked the Stop hook without a transcript payload on stdin; no usage event can be created.",
        )
        return

    try:
        payload = json.loads(raw_payload)
    except Exception:
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "invalid_json")
        return

    if not isinstance(payload, dict):
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "non_object_payload")
        return

    transcript_path = payload.get("transcript_path", "")
    session_id = payload.get("session_id", "")

    if not transcript_path:
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "missing_transcript_path", payload)
        return

    if not pathlib.Path(transcript_path).is_file():
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "transcript_unavailable", payload)
        return

    # Collect all assistant messages across the entire session.
    # cache_read grows cumulatively — exclude it to avoid double-counting.
    all_turns: list[dict] = []
    current_group: list[dict] = []
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
                        all_turns.extend(current_group)
                        current_group = []
                    elif role == "assistant" and "usage" in msg:
                        current_group.append(msg)
                except Exception:
                    pass
        # Include any trailing assistant messages (current turn in progress).
        all_turns.extend(current_group)
    except Exception:
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "transcript_read_failed", payload)
        return

    if not all_turns:
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "no_usage_hook_call",
            "no_assistant_usage",
            payload,
            meaning="Claude Stop hook ran, but the transcript did not expose assistant usage records for this stop.",
        )
        return

    # Collect tool names from all turns (name field only, not inputs).
    tool_names: set[str] = set()
    for turn in all_turns:
        for item in turn.get("content", []):
            if isinstance(item, dict) and item.get("type") == "tool_use":
                name = item.get("name", "")
                if name:
                    tool_names.add(name)

    # fresh = new tokens actually sent this session (input + cache_creation per turn).
    # cache_read_input_tokens is excluded: it is the re-read accumulated context and
    # grows with every turn, causing massive overcounting if included.
    session_fresh = sum(
        t["usage"].get("input_tokens", 0) + t["usage"].get("cache_creation_input_tokens", 0)
        for t in all_turns
    )
    session_output = sum(t["usage"].get("output_tokens", 0) for t in all_turns)

    if session_fresh == 0 and session_output == 0:
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "no_usage_hook_call",
            "zero_token_usage",
            payload,
            meaning="Claude Stop hook ran, but exact token usage totals were zero.",
        )
        return

    raw_model = all_turns[-1].get("model", "")
    model = raw_model if _MODEL_ID.match(raw_model) else "claude-unknown"

    run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])

    # Delta tracking: emit only NEW tokens since the last Stop fire for this session.
    prev_fresh, prev_output = _load_session_state(run_id)
    fresh = session_fresh - prev_fresh
    output = session_output - prev_output
    total = fresh + output

    if total <= 0:
        # No new tokens since last fire — update state in case this is the first run.
        if prev_fresh == 0 and prev_output == 0:
            _save_session_state(run_id, session_fresh, session_output)
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "no_usage_hook_call",
            "no_new_token_delta",
            payload,
            meaning="Claude Stop hook ran, but this session checkpoint had no new exact usage delta to enqueue.",
        )
        return

    _save_session_state(run_id, session_fresh, session_output)

    # span_id encodes the cumulative session position so the same checkpoint deduplicates.
    span_id = _stable_span_id(run_id, model, str(session_fresh), str(session_output))
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
        "input_tokens": fresh,
        "output_tokens": output,
        "total_tokens": total,
        "token_breakdown": {
            "system": 0,
            "user": 0,
            "history": 0,
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
    _write_success_diagnostic(event)
    _consume_label_file()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
