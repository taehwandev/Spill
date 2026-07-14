#!/usr/bin/env python3
"""
Spill token metering adapter for Claude Code.

Reads the Stop hook payload from stdin, extracts new turns' token usage
from the Claude Code transcript, and enqueues safe JSON event files in the
Spill local queue.

Token counting: sums input_tokens, cache_creation_input_tokens, and
cache_read_input_tokens plus output_tokens per turn so Claude Code raw usage
matches the Codex measurement baseline. When a runtime omits top-level usage
totals but exposes exact per-iteration usage, the hook falls back to those
iteration totals.

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
LABEL_TIMELINE_FILE = pathlib.Path(str(LABEL_FILE).removesuffix(".json") + "-timeline.jsonl")
DIAGNOSTICS_DIR = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/diagnostics",
    )
)
EMPTY_DIAGNOSTIC_FILE_NAME = "claude-last-empty.json"
MISMATCH_DIAGNOSTIC_FILE_NAME = "claude-last-mismatch.json"


def _ensure_private_dir(path: pathlib.Path) -> None:
    """Create path (and parents) restricted to the owner and re-assert 0700 even if the
    directory already existed, so upgrades from an earlier version that created these
    directories with default (looser, umask-based) permissions get hardened too. These
    directories hold unauthenticated local usage events and session state that any other
    local account should not be able to read or write into.
    """
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        os.chmod(path, 0o700)
    except OSError:
        pass


SUCCESS_DIAGNOSTIC_FILE_NAME = "claude-last-success.json"
_OPAQUE_ID = re.compile(r'^[A-Za-z0-9_-]{6,64}$')
_MODEL_ID = re.compile(r'^[A-Za-z0-9_.:-]{2,80}$')
_SAFE_SLUG = re.compile(r'^[a-z][a-z0-9_]{1,40}$')

_USED_LABEL_FILE = False
_SCAN_IMPORTED = "imported"
_SCAN_SKIPPED = "skipped"
_SCAN_UNSUPPORTED = "unsupported"


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


def _safe_project_id(payload: dict) -> str:
    global _USED_LABEL_FILE
    payload_project_id = _payload_value(payload, "project_id", "projectID")
    if _OPAQUE_ID.match(payload_project_id):
        return payload_project_id

    for env_key in ("SPILL_TOKEN_USAGE_PROJECT_ID", "SPILL_PROJECT_ID"):
        env_project_id = os.environ.get(env_key, "")
        if _OPAQUE_ID.match(env_project_id):
            return env_project_id

    file_project_id = _label_file_value("project_id", "projectID")
    if _OPAQUE_ID.match(file_project_id):
        _USED_LABEL_FILE = True
        return file_project_id

    return "project_global"


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


def _parse_token_usage_datetime(value: str):
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


def _label_timeline_for_timestamp(timestamp: str) -> dict:
    event_time = _parse_token_usage_datetime(timestamp)
    if event_time is None:
        return {}

    best = None
    try:
        lines = LABEL_TIMELINE_FILE.read_text().splitlines()
    except Exception:
        return {}

    for line in lines:
        if not line.strip():
            continue
        try:
            data = json.loads(line)
        except Exception:
            continue
        if not isinstance(data, dict):
            continue
        tool = data.get("ai_tool", "")
        if tool not in ("", "unknown", "claude"):
            continue
        task_type = data.get("task_type", "")
        stage = data.get("stage", "")
        if not _SAFE_SLUG.match(task_type) and not _SAFE_SLUG.match(stage):
            continue
        updated_at = _parse_token_usage_datetime(data.get("updated_at", ""))
        expires_at = _parse_token_usage_datetime(data.get("expires_at", ""))
        if updated_at is None or expires_at is None:
            continue
        if not (updated_at <= event_time <= expires_at):
            continue
        if best is None or updated_at > best["updated_at"]:
            project_id = data.get("project_id", "")
            best = {
                "task_type": task_type if _SAFE_SLUG.match(task_type) else "",
                "stage": stage if _SAFE_SLUG.match(stage) else "",
                "project_id": project_id if _OPAQUE_ID.match(project_id) else "",
                "updated_at": updated_at,
            }

    if best is None:
        return {}
    return {
        "task_type": best["task_type"],
        "stage": best["stage"],
        "project_id": best["project_id"],
    }


def _accounting_record_for_event(event: dict, accounting=None):
    if not accounting:
        return None
    return {
        "schema_version": 1,
        "span_id": event["span_id"],
        "ai_tool": event["ai_tool"],
        "uncached_input_tokens": accounting.get("uncached_input_tokens", 0),
        "cache_creation_input_tokens": accounting.get("cache_creation_input_tokens", 0),
        "cache_read_input_tokens": accounting.get("cache_read_input_tokens", 0),
        "reasoning_output_tokens": accounting.get("reasoning_output_tokens", 0),
    }


def _event_record(event: dict, accounting=None) -> dict:
    return {
        "event": event,
        "accounting": _accounting_record_for_event(event, accounting),
    }


def _enqueue_event(event: dict, accounting=None) -> None:
    _ensure_private_dir(INBOX_DIR)
    event_id = uuid.uuid4().hex
    temporary_path = INBOX_DIR / f".{event_id}.tmp"
    final_path = INBOX_DIR / f"{event_id}.json"
    accounting_temporary_path = INBOX_DIR / f".{event_id}.accounting.tmp"
    accounting_final_path = INBOX_DIR / f"{event_id}.accounting"

    with open(temporary_path, "x") as f:
        f.write(json.dumps(event, separators=(",", ":")))
    os.chmod(temporary_path, 0o600)
    accounting_record = _accounting_record_for_event(event, accounting)
    if accounting_record:
        with open(accounting_temporary_path, "x") as f:
            f.write(json.dumps(accounting_record, separators=(",", ":")))
            f.write("\n")
        os.chmod(accounting_temporary_path, 0o600)
        os.replace(accounting_temporary_path, accounting_final_path)
    os.replace(temporary_path, final_path)


def _enqueue_events(records: list[dict]) -> None:
    if not records:
        return
    _ensure_private_dir(INBOX_DIR)
    event_id = uuid.uuid4().hex
    temporary_path = INBOX_DIR / f".{event_id}.tmp"
    final_path = INBOX_DIR / f"{event_id}.jsonl"
    accounting_temporary_path = INBOX_DIR / f".{event_id}.accounting.tmp"
    accounting_final_path = INBOX_DIR / f"{event_id}.accounting"

    with open(temporary_path, "x") as f:
        for record in records:
            event = record.get("event", record)
            f.write(json.dumps(event, separators=(",", ":")))
            f.write("\n")
    os.chmod(temporary_path, 0o600)
    accounting_records = [record.get("accounting") for record in records if record.get("accounting")]
    if accounting_records:
        with open(accounting_temporary_path, "x") as f:
            for accounting_record in accounting_records:
                f.write(json.dumps(accounting_record, separators=(",", ":")))
                f.write("\n")
        os.chmod(accounting_temporary_path, 0o600)
        os.replace(accounting_temporary_path, accounting_final_path)
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


def _safe_usage_token(value) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return max(0, value)
    if isinstance(value, float) and value.is_integer():
        return max(0, int(value))
    return 0


def _cache_creation_tokens(usage: dict) -> int:
    direct = _safe_usage_token(usage.get("cache_creation_input_tokens"))
    if direct > 0:
        return direct

    detail = usage.get("cache_creation")
    if not isinstance(detail, dict):
        return 0
    return sum(_safe_usage_token(value) for value in detail.values())


def _usage_amounts(usage: dict, include_iterations: bool = True) -> tuple[int, int, int]:
    if not isinstance(usage, dict):
        return 0, 0, 0

    input_tokens = _safe_usage_token(usage.get("input_tokens"))
    cache_creation_tokens = _cache_creation_tokens(usage)
    cache_read_tokens = _safe_usage_token(usage.get("cache_read_input_tokens"))
    output_tokens = _safe_usage_token(usage.get("output_tokens"))

    if input_tokens > 0 or cache_creation_tokens > 0 or cache_read_tokens > 0 or output_tokens > 0:
        return (
            input_tokens + cache_creation_tokens + cache_read_tokens,
            input_tokens + cache_creation_tokens,
            output_tokens,
        )

    if not include_iterations:
        return 0, 0, 0

    iterations = usage.get("iterations")
    if not isinstance(iterations, list):
        return 0, 0, 0

    total_input = 0
    total_span_input = 0
    total_output = 0
    for item in iterations:
        if not isinstance(item, dict):
            continue
        nested_usage = item.get("usage") if isinstance(item.get("usage"), dict) else item
        nested_input, nested_span_input, nested_output = _usage_amounts(nested_usage, include_iterations=False)
        total_input += nested_input
        total_span_input += nested_span_input
        total_output += nested_output
    return total_input, total_span_input, total_output


def _usage_accounting(usage: dict, include_iterations: bool = True) -> dict:
    zero = {
        "uncached_input_tokens": 0,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": 0,
        "reasoning_output_tokens": 0,
    }
    if not isinstance(usage, dict):
        return zero

    input_tokens = _safe_usage_token(usage.get("input_tokens"))
    cache_creation_tokens = _cache_creation_tokens(usage)
    cache_read_tokens = _safe_usage_token(usage.get("cache_read_input_tokens"))
    output_tokens = _safe_usage_token(usage.get("output_tokens"))

    if input_tokens > 0 or cache_creation_tokens > 0 or cache_read_tokens > 0 or output_tokens > 0:
        return {
            "uncached_input_tokens": input_tokens,
            "cache_creation_input_tokens": cache_creation_tokens,
            "cache_read_input_tokens": cache_read_tokens,
            "reasoning_output_tokens": 0,
        }

    if not include_iterations:
        return zero

    iterations = usage.get("iterations")
    if not isinstance(iterations, list):
        return zero

    totals = dict(zero)
    for item in iterations:
        if not isinstance(item, dict):
            continue
        nested_usage = item.get("usage") if isinstance(item.get("usage"), dict) else item
        nested = _usage_accounting(nested_usage, include_iterations=False)
        for key in totals:
            totals[key] += nested[key]
    return totals


def _usage_totals(usage: dict, include_iterations: bool = True) -> tuple[int, int]:
    input_tokens, _, output_tokens = _usage_amounts(usage, include_iterations=include_iterations)
    return input_tokens, output_tokens


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
        _ensure_private_dir(DIAGNOSTICS_DIR)
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
        _ensure_private_dir(DIAGNOSTICS_DIR)
        final_path = DIAGNOSTICS_DIR / SUCCESS_DIAGNOSTIC_FILE_NAME
        temporary_path = DIAGNOSTICS_DIR / f".{SUCCESS_DIAGNOSTIC_FILE_NAME}.tmp"
        with open(temporary_path, "w") as f:
            f.write(json.dumps(diagnostic, separators=(",", ":")))
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, final_path)
    except Exception:
        pass

    _clear_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME)
    _clear_diagnostic_file(EMPTY_DIAGNOSTIC_FILE_NAME)


def _clear_diagnostic_file(filename: str) -> None:
    try:
        (DIAGNOSTICS_DIR / filename).unlink()
    except Exception:
        pass


def _stable_span_id(*parts: str) -> str:
    source = ":".join(parts)
    return "span-" + hashlib.sha256(source.encode("utf-8")).hexdigest()[:12]


def _state_int(data: dict, key: str) -> int:
    try:
        value = int(data.get(key, 0))
    except Exception:
        return 0
    return max(0, value)


def _state_request_ids(data: dict) -> set[str]:
    values = data.get("emitted_request_ids", [])
    if not isinstance(values, list):
        return set()
    return {value for value in values if isinstance(value, str) and value}


def _load_session_state(run_id: str) -> tuple[int, int, int, set[str], int]:
    """Return (prev_fresh, prev_output, byte_offset, emitted_request_ids, next_turn_index).

    next_turn_index is the cumulative turn count from the start of the transcript file,
    matching the Swift active importer's next_turn_index_by_source. It only affects
    span_id when a turn's requestId is empty (span_id is requestId-stable otherwise, and
    does not depend on turn_index at all), so a legacy state file written before
    next_turn_index existed can safely default it to 0 and resume from its existing
    byte_offset rather than forcing a full re-scan of the transcript.
    """
    state_path = SESSION_STATE_DIR / f"{run_id}.json"
    try:
        data = json.loads(state_path.read_text())
        if isinstance(data, dict):
            fresh = _state_int(data, "fresh") or _state_int(data, "input")
            return (
                fresh,
                _state_int(data, "output"),
                _state_int(data, "byte_offset"),
                _state_request_ids(data),
                _state_int(data, "next_turn_index"),
            )
    except Exception:
        pass
    return 0, 0, 0, set(), 0


def _save_session_state(
    run_id: str,
    fresh: int,
    output: int,
    byte_offset: int,
    emitted_request_ids=None,
    next_turn_index: int = 0,
) -> None:
    try:
        _ensure_private_dir(SESSION_STATE_DIR)
        state_path = SESSION_STATE_DIR / f"{run_id}.json"
        tmp_path = SESSION_STATE_DIR / f".{run_id}.tmp"
        tmp_path.write_text(json.dumps({
            "fresh": max(0, fresh),
            "output": max(0, output),
            "byte_offset": max(0, byte_offset),
            "next_turn_index": max(0, next_turn_index),
            "emitted_request_ids": sorted(emitted_request_ids or set()),
        }))
        os.replace(tmp_path, state_path)
    except Exception:
        pass


def _request_id_for_turn(turn: dict) -> str:
    request_id = turn.get("request_id", "")
    return request_id if isinstance(request_id, str) else ""


def _consume_label_file() -> None:
    if not _USED_LABEL_FILE:
        return
    try:
        LABEL_FILE.unlink()
    except Exception:
        pass


def _turn_from_record(obj: dict):
    msg = obj.get("message", {})
    if not isinstance(msg, dict) or msg.get("role", "") != "assistant":
        return None
    ts = obj.get("timestamp", "")
    request_id = obj.get("requestId", "") or msg.get("id", "") or obj.get("uuid", "")
    if isinstance(msg.get("usage"), dict):
        turn = dict(msg)
        if isinstance(request_id, str) and request_id:
            turn["request_id"] = request_id
        if ts:
            turn["timestamp"] = ts
        return turn
    if isinstance(obj.get("usage"), dict):
        turn = {
            "model": msg.get("model", ""),
            "usage": obj.get("usage", {}),
            "content": msg.get("content", []),
        }
        if isinstance(request_id, str) and request_id:
            turn["request_id"] = request_id
        if ts:
            turn["timestamp"] = ts
        return turn
    return None


def _history_turn_sort_key(turn: dict) -> tuple[str, int]:
    timestamp = turn.get("timestamp", "")
    return (timestamp if isinstance(timestamp, str) else "", int(turn.get("turn_index", 0) or 0))


def _deduplicate_transcript_turns(turns: list[dict], starting_index: int = 0) -> list[dict]:
    keyed: dict[str, dict] = {}
    passthrough: list[dict] = []

    for turn in turns:
        request_id = turn.get("request_id", "")
        if not isinstance(request_id, str) or not request_id:
            passthrough.append(turn)
            continue

        # Always keep the FIRST occurrence of each requestId. This matches the
        # cross-batch emitted_request_ids rule and the Swift importer's
        # deduplicateAssistantTurns behavior so both paths produce the same span_id.
        if request_id not in keyed:
            keyed[request_id] = turn

    deduplicated = passthrough + list(keyed.values())
    deduplicated.sort(key=_history_turn_sort_key)
    # Use starting_index so turn_index values are cumulative across incremental reads,
    # matching the Swift active importer's nextTurnIndexBySource for identical span_ids.
    for index, turn in enumerate(deduplicated, start=starting_index):
        turn["turn_index"] = index
    return deduplicated


def _read_transcript_turns(transcript_path: str, byte_offset: int, starting_turn_index: int = 0) -> tuple[list[dict], int, int, int]:
    start_offset = max(0, byte_offset)
    try:
        file_size = pathlib.Path(transcript_path).stat().st_size
    except Exception:
        file_size = 0
    if start_offset > file_size:
        start_offset = 0

    all_turns: list[dict] = []
    current_group: list[dict] = []
    end_offset = start_offset
    # Relative turn_index for intra-batch sort/dedup selection only;
    # _deduplicate_transcript_turns reassigns absolute indices from starting_turn_index.
    turn_index = 0

    with open(transcript_path, "rb") as f:
        f.seek(start_offset)
        while True:
            raw = f.readline()
            if not raw:
                break
            end_offset = f.tell()
            try:
                obj = json.loads(raw.decode("utf-8").strip())
                msg = obj.get("message", {})
                role = msg.get("role", "") if isinstance(msg, dict) else ""
                if role in {"human", "user"}:
                    all_turns.extend(current_group)
                    current_group = []
                else:
                    turn = _turn_from_record(obj)
                    if turn is not None:
                        turn["turn_index"] = turn_index
                        turn_index += 1
                        current_group.append(turn)
            except Exception:
                pass

    all_turns.extend(current_group)
    result = _deduplicate_transcript_turns(all_turns, starting_index=starting_turn_index)
    return result, end_offset, start_offset, starting_turn_index + len(result)


def _turns_after_prior_cumulative(
    turns: list[dict],
    previous_input: int,
    previous_output: int,
    read_start_offset: int,
) -> list[dict]:
    if read_start_offset > 0 or (previous_input <= 0 and previous_output <= 0):
        return turns

    filtered: list[dict] = []
    running_input = 0
    running_output = 0
    for turn in turns:
        turn_input, turn_output = _usage_totals(turn.get("usage", {}))
        next_input = running_input + turn_input
        next_output = running_output + turn_output
        if next_input > previous_input or next_output > previous_output:
            filtered.append(turn)
        running_input = next_input
        running_output = next_output
    return filtered


def _event_for_live_turn(
    run_id: str,
    turn: dict,
    payload: dict,
    allow_current_label: bool,
    allow_timestamp_fallback: bool,
):
    turn_input, turn_span_input, turn_output = _usage_amounts(turn.get("usage", {}))
    total = turn_input + turn_output
    if total <= 0:
        return None

    timestamp = turn.get("timestamp", "")
    if not timestamp:
        if not allow_timestamp_fallback:
            return None
        timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

    raw_model = turn.get("model", "")
    model = raw_model if _MODEL_ID.match(raw_model) else "claude-unknown"
    inferred_task_type = 'uncategorized'
    inferred_stage = 'summarize'
    label = _label_timeline_for_timestamp(timestamp)

    task_type = label.get("task_type") if _SAFE_SLUG.match(label.get("task_type", "")) else ""
    stage = label.get("stage") if _SAFE_SLUG.match(label.get("stage", "")) else ""
    project_id = label.get("project_id") if _OPAQUE_ID.match(label.get("project_id", "")) else ""

    if allow_current_label:
        if not task_type:
            task_type = _safe_label(
                payload,
                ("task_type", "taskType"),
                ("SPILL_TOKEN_USAGE_TASK_TYPE", "SPILL_WORKFLOW_TASK_TYPE"),
                inferred_task_type,
            )
        if not stage:
            stage = _safe_label(
                payload,
                ("stage", "workflow_stage", "workflowStage"),
                ("SPILL_TOKEN_USAGE_STAGE", "SPILL_WORKFLOW_STAGE"),
                inferred_stage,
            )
        if not project_id:
            project_id = _safe_project_id(payload)
    else:
        if not task_type:
            task_type = inferred_task_type
        if not stage:
            stage = inferred_stage
        if not project_id:
            project_id = "project_global"

    request_id_str = str(turn.get("request_id", ""))
    if request_id_str:
        # requestId-stable formula: Bug #2 writes the same requestId 2-3x with
        # different timestamps. Omitting turn_index and timestamp makes all
        # occurrences produce the same span_id so the DB PRIMARY KEY deduplicates
        # them, regardless of which occurrence Python or Swift processed first.
        span_id = _stable_span_id(run_id, model, request_id_str, str(turn_span_input), str(turn_output))
    else:
        span_id = _stable_span_id(run_id, model, "", str(turn.get("turn_index", "")), timestamp, str(turn_span_input), str(turn_output))

    return {
        "schema_version": 1,
        "device_id": "device_local",
        "project_id": project_id,
        "artifact_id": "artifact_global",
        "run_id": run_id,
        "span_id": span_id,
        "ai_tool": "claude",
        "task_type": task_type,
        "stage": stage,
        "model": model,
        "input_tokens": turn_input,
        "output_tokens": turn_output,
        "total_tokens": total,
        "token_breakdown": {
            "system": 0,
            "user": 0,
            "history": 0,
            "repo_context": 0,
            "tool_output": 0,
            "generated_output": turn_output,
            "unknown": turn_input,
        },
        "latency_ms": 0,
        "created_at": timestamp,
    }


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

    _run_for_payload(payload)


def _run_history_payload(payload: dict, enqueue_event=_enqueue_event, flush_events=None) -> dict:
    transcript_path = payload.get("transcript_path", "")
    session_id = payload.get("session_id", "")
    run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])
    result = {"imported_events": 0, "skipped_seen": 0, "unsupported_records": 0}

    if not transcript_path or not pathlib.Path(transcript_path).is_file():
        result["unsupported_records"] += 1
        return result

    prev_fresh, prev_output, previous_byte_offset, emitted_request_ids, starting_turn_index = _load_session_state(run_id)
    try:
        all_turns, transcript_byte_offset, read_start_offset, next_turn_index = _read_transcript_turns(
            transcript_path,
            previous_byte_offset,
            starting_turn_index,
        )
    except Exception:
        result["unsupported_records"] += 1
        return result

    if not all_turns:
        if transcript_byte_offset > previous_byte_offset:
            _save_session_state(run_id, prev_fresh, prev_output, transcript_byte_offset, emitted_request_ids, starting_turn_index)
        if previous_byte_offset > 0:
            result["skipped_seen"] += 1
        else:
            result["unsupported_records"] += 1
        return result

    session_fresh = 0
    session_output = 0
    emitted_any = False
    next_emitted_request_ids = set(emitted_request_ids)
    for turn in all_turns:
        turn_input, turn_span_input, turn_output = _usage_amounts(turn.get("usage", {}))
        session_fresh += turn_input
        session_output += turn_output
        total = turn_input + turn_output
        if total <= 0:
            result["unsupported_records"] += 1
            continue

        timestamp = turn.get("timestamp", "")
        if not timestamp:
            result["unsupported_records"] += 1
            continue
        request_id = _request_id_for_turn(turn)
        if request_id and request_id in emitted_request_ids:
            result["skipped_seen"] += 1
            continue

        raw_model = turn.get("model", "")
        model = raw_model if _MODEL_ID.match(raw_model) else "claude-unknown"
        label = _label_timeline_for_timestamp(timestamp)
        task_type = label.get("task_type") if _SAFE_SLUG.match(label.get("task_type", "")) else "uncategorized"
        stage = label.get("stage") if _SAFE_SLUG.match(label.get("stage", "")) else "summarize"
        project_id = label.get("project_id") if _OPAQUE_ID.match(label.get("project_id", "")) else "project_global"
        _req_id = str(turn.get("request_id", ""))
        span_id = (
            _stable_span_id(run_id, model, _req_id, str(turn_span_input), str(turn_output))
            if _req_id
            else _stable_span_id(run_id, model, "", str(turn.get("turn_index", "")), timestamp, str(turn_span_input), str(turn_output))
        )

        event = {
            "schema_version": 1,
            "device_id": "device_local",
            "project_id": project_id,
            "artifact_id": "artifact_global",
            "run_id": run_id,
            "span_id": span_id,
            "ai_tool": "claude",
            "task_type": task_type,
            "stage": stage,
            "model": model,
            "input_tokens": turn_input,
            "output_tokens": turn_output,
            "total_tokens": total,
            "token_breakdown": {
                "system": 0,
                "user": 0,
                "history": 0,
                "repo_context": 0,
                "tool_output": 0,
                "generated_output": turn_output,
                "unknown": turn_input,
            },
            "latency_ms": 0,
            "created_at": timestamp,
        }
        enqueue_event(event, _usage_accounting(turn.get("usage", {})))
        if request_id:
            next_emitted_request_ids.add(request_id)
        emitted_any = True
        result["imported_events"] += 1

    if emitted_any:
        if flush_events is not None:
            flush_events()
        _save_session_state(
            run_id,
            prev_fresh + session_fresh if read_start_offset > 0 else session_fresh,
            prev_output + session_output if read_start_offset > 0 else session_output,
            transcript_byte_offset,
            next_emitted_request_ids,
            next_turn_index,
        )
    elif transcript_byte_offset > previous_byte_offset:
        _save_session_state(run_id, prev_fresh, prev_output, transcript_byte_offset, next_emitted_request_ids, next_turn_index)

    return result


def _run_for_payload(payload: dict, scan_subagents: bool = True, allow_timestamp_fallback: bool = True) -> str:
    transcript_path = payload.get("transcript_path", "")
    session_id = payload.get("session_id", "")
    run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])

    if not transcript_path:
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "missing_transcript_path", payload)
        return _SCAN_UNSUPPORTED

    if not pathlib.Path(transcript_path).is_file():
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "transcript_unavailable", payload)
        return _SCAN_UNSUPPORTED

    prev_fresh, prev_output, previous_byte_offset, emitted_request_ids, starting_turn_index = _load_session_state(run_id)
    try:
        all_turns, transcript_byte_offset, read_start_offset, next_turn_index = _read_transcript_turns(
            transcript_path,
            previous_byte_offset,
            starting_turn_index,
        )
    except Exception:
        _write_diagnostic_file(MISMATCH_DIAGNOSTIC_FILE_NAME, "runtime_payload_mismatch", "transcript_read_failed", payload)
        return _SCAN_UNSUPPORTED

    if not all_turns:
        if transcript_byte_offset > previous_byte_offset:
            _save_session_state(run_id, prev_fresh, prev_output, transcript_byte_offset, emitted_request_ids, starting_turn_index)
        reason = "no_new_token_delta" if previous_byte_offset > 0 else "no_assistant_usage"
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "no_usage_hook_call",
            reason,
            payload,
            meaning="Claude Stop hook ran, but no new assistant usage records were available for this stop.",
        )
        return _SCAN_SKIPPED if reason == "no_new_token_delta" else _SCAN_UNSUPPORTED

    # Input total includes fresh, cache-write, and cache-read token categories.
    session_fresh = 0
    session_output = 0
    for turn in all_turns:
        turn_input, turn_output = _usage_totals(turn.get("usage", {}))
        session_fresh += turn_input
        session_output += turn_output

    if session_fresh == 0 and session_output == 0:
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "no_usage_hook_call",
            "zero_token_usage",
            payload,
            meaning="Claude Stop hook ran, but exact token usage totals were zero.",
        )
        return _SCAN_UNSUPPORTED

    is_incremental_read = read_start_offset > 0
    if is_incremental_read:
        next_fresh = prev_fresh + session_fresh
        next_output = prev_output + session_output
    else:
        # Full-scan fallback for first run, old state files, or transcript truncation.
        next_fresh = session_fresh
        next_output = session_output

    turns_to_emit = _turns_after_prior_cumulative(
        all_turns,
        prev_fresh,
        prev_output,
        read_start_offset,
    )
    turns_to_emit = [
        turn
        for turn in turns_to_emit
        if not (request_id := _request_id_for_turn(turn)) or request_id not in emitted_request_ids
    ]
    allow_current_label = len(turns_to_emit) == 1
    events = [
        (turn, event)
        for turn in turns_to_emit
        if (event := _event_for_live_turn(
            run_id,
            turn,
            payload,
            allow_current_label=allow_current_label,
            allow_timestamp_fallback=allow_timestamp_fallback,
        )) is not None
    ]

    next_emitted_request_ids = set(emitted_request_ids)
    if not events:
        _save_session_state(run_id, next_fresh, next_output, transcript_byte_offset, next_emitted_request_ids, next_turn_index)
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "no_usage_hook_call",
            "no_new_token_delta",
            payload,
            meaning="Claude Stop hook ran, but this session checkpoint had no new exact usage delta to enqueue.",
        )
        return _SCAN_SKIPPED

    for turn, event in events:
        _enqueue_event(event, _usage_accounting(turn.get("usage", {})))
        request_id = _request_id_for_turn(turn)
        if request_id:
            next_emitted_request_ids.add(request_id)
    _save_session_state(run_id, next_fresh, next_output, transcript_byte_offset, next_emitted_request_ids, next_turn_index)
    _write_success_diagnostic(events[-1][1])
    _consume_label_file()
    if scan_subagents:
        _scan_session_subagents(transcript_path)
    return _SCAN_IMPORTED


def _scan_session_subagents(transcript_path: str) -> None:
    """Scan likely subagents directories near the main transcript on Stop-hook invocation."""
    global _USED_LABEL_FILE
    transcript = pathlib.Path(transcript_path)
    saved = _USED_LABEL_FILE
    try:
        subagents_dir = transcript.parent / "subagents"
        if subagents_dir.is_dir():
            scan_main(str(subagents_dir), since_hours=24 * 30)
    except Exception:
        pass
    finally:
        _USED_LABEL_FILE = saved


def scan_main(scan_dir: str, since_hours) -> dict:
    """Scan *.jsonl transcripts under scan_dir modified within since_hours and enqueue usage events."""
    import time
    global _USED_LABEL_FILE
    scan_path = pathlib.Path(scan_dir)
    if not scan_path.is_dir():
        return {
            "scanned_files": 0,
            "imported_events": 0,
            "skipped_seen": 0,
            "unsupported_records": 0,
        }
    cutoff_mtime = None if since_hours is None else time.time() - since_hours * 3600
    scanned_files = 0
    imported_events = 0
    skipped_seen = 0
    unsupported_records = 0
    pending_events: list[dict] = []

    def enqueue_history_event(event: dict, accounting=None) -> None:
        pending_events.append(_event_record(event, accounting))
        if len(pending_events) >= 5000:
            _enqueue_events(pending_events)
            pending_events.clear()

    def flush_history_events() -> None:
        _enqueue_events(pending_events)
        pending_events.clear()

    for jsonl_file in sorted(scan_path.rglob("*.jsonl")):
        try:
            if cutoff_mtime is not None and jsonl_file.stat().st_mtime < cutoff_mtime:
                continue
            scanned_files += 1
            _USED_LABEL_FILE = False  # don't consume the live label file for historical transcripts
            stem = jsonl_file.stem
            session_id = stem if _OPAQUE_ID.match(stem) else ""
            result = _run_history_payload(
                {
                    "transcript_path": str(jsonl_file),
                    "session_id": session_id,
                },
                enqueue_event=enqueue_history_event,
                flush_events=flush_history_events,
            )
            imported_events += result["imported_events"]
            skipped_seen += result["skipped_seen"]
            unsupported_records += result["unsupported_records"]
        except Exception:
            unsupported_records += 1
            pass
        finally:
            _USED_LABEL_FILE = False
    flush_history_events()
    return {
        "scanned_files": scanned_files,
        "imported_events": imported_events,
        "skipped_seen": skipped_seen,
        "unsupported_records": unsupported_records,
    }


if __name__ == "__main__":
    _args = sys.argv[1:]
    if "--scan-dir" in _args:
        _idx = _args.index("--scan-dir")
        _scan_dir = _args[_idx + 1] if _idx + 1 < len(_args) else ""
        _since_hours = None if "--all" in _args else 24
        if "--since-hours" in _args:
            _h = _args.index("--since-hours")
            try:
                _since_hours = int(_args[_h + 1])
            except Exception:
                pass
        try:
            _summary = scan_main(_scan_dir, _since_hours)
            if "--json" in _args:
                print(json.dumps(_summary, separators=(",", ":")))
        except Exception:
            if "--json" in _args:
                print(json.dumps({
                    "scanned_files": 0,
                    "imported_events": 0,
                    "skipped_seen": 0,
                    "unsupported_records": 0,
                    "error": "scan_failed",
                }, separators=(",", ":")))
            sys.exit(1)
    else:
        try:
            main()
        except Exception:
            pass
