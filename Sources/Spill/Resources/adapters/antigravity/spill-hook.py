#!/usr/bin/env python3
"""
Spill token metering adapter for Antigravity (AGY).

Reads the AGY PostInvocation or Stop hook payload from stdin, extracts exact
token usage from the hook payload, and enqueues one JSON event file in the
Spill local queue.

Install: configure AGY to call this script as a PostInvocation or Stop hook in ~/.gemini/config/hooks.json.
"""
import datetime
import hashlib
import json
import os
import pathlib
import re
import select
import sys
import uuid

INBOX_DIR = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_INBOX_DIR",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/events-inbox",
    )
)
DIAGNOSTICS_DIR = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/diagnostics",
    )
)
EMPTY_DIAGNOSTIC_FILE_NAME = "antigravity-last-empty.json"
MISMATCH_DIAGNOSTIC_FILE_NAME = "antigravity-last-mismatch.json"
SUCCESS_DIAGNOSTIC_FILE_NAME = "antigravity-last-success.json"
LEGACY_DIAGNOSTIC_FILE_NAME = "antigravity-latest.json"
LABEL_FILE = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_LABEL_FILE",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/label-context/antigravity.json",
    )
)
_OPAQUE_ID = re.compile(r'^[A-Za-z0-9_-]{6,64}$')
_MODEL_ID = re.compile(r'^[A-Za-z0-9_.:-]{2,80}$')
_SAFE_SLUG = re.compile(r'^[a-z][a-z0-9_]{1,40}$')
_USED_LABEL_FILE = False


def _opaque(value: str, fallback: str) -> str:
    return value if _OPAQUE_ID.match(value) else fallback


def _safe_slug(value: str, fallback: str) -> str:
    return value if _SAFE_SLUG.match(value) else fallback


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
    if tool not in ("", "unknown", "antigravity", "agy"):
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


def _write_diagnostic_file(filename: str, kind: str, reason: str, payload: dict = None, meaning: str = "") -> None:
    if os.environ.get("SPILL_TOKEN_USAGE_DISABLE_DIAGNOSTICS") == "1":
        return

    diagnostic = {
        "schema_version": 1,
        "ai_tool": "antigravity",
        "kind": kind,
        "reason": reason,
        "created_at": _diagnostic_timestamp(),
        "expected_input_contracts": [
            "top_level_input_output_tokens",
            "usage_input_output_tokens",
            "tokens_input_output",
            "usage_metadata_total_tokens",
            "spill_token_usage_normalized",
        ],
        "observed_safe_shape": _safe_payload_shape(payload),
        "privacy": "No payload values, prompts, commands, file paths, logs, diffs, source, environment values, or secrets are stored.",
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
        "ai_tool": "antigravity",
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
        "privacy": "No prompts, commands, file paths, logs, diffs, source, environment values, secrets, run ids, or span ids are stored.",
    }

    try:
        DIAGNOSTICS_DIR.mkdir(parents=True, exist_ok=True)
        final_path = DIAGNOSTICS_DIR / SUCCESS_DIAGNOSTIC_FILE_NAME
        temporary_path = DIAGNOSTICS_DIR / f".{SUCCESS_DIAGNOSTIC_FILE_NAME}.tmp"
        with open(temporary_path, "w") as f:
            f.write(json.dumps(diagnostic, separators=(",", ":")))
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, final_path)
    except Exception:
        pass


def _safe_payload_shape(payload: dict = None) -> dict:
    if not isinstance(payload, dict):
        return {
            "payload_object": False,
            "has_exact_input_output": False,
            "has_total_only": False,
            "has_model_hint": False,
            "has_opaque_run_hint": False,
        }

    containers = _token_containers(payload)
    return {
        "payload_object": True,
        "has_exact_input_output": _has_any_int_field(containers, _INPUT_TOKEN_KEYS)
        or _has_any_int_field(containers, _OUTPUT_TOKEN_KEYS)
        or _has_tokens_alias_input_output(payload),
        "has_total_only": _has_any_int_field(containers, _TOTAL_TOKEN_KEYS),
        "has_model_hint": bool(_payload_model_hint(payload)),
        "has_opaque_run_hint": any(isinstance(payload.get(key), str) for key in ("session_id", "conversationId")),
    }


def _stable_span_id(*parts: str) -> str:
    source = ":".join(parts)
    return "span-" + hashlib.sha256(source.encode("utf-8")).hexdigest()[:12]


def _payload_model_hint(payload: dict) -> str:
    keys = ("model", "model_name", "modelName", "model_id", "modelId", "modelVersion")
    for container in (
        payload,
        payload.get("spill_token_usage", {}),
        payload.get("spillTokenUsage", {}),
        payload.get("token_usage", {}),
        payload.get("tokenUsage", {}),
        payload.get("llm_request", {}),
        payload.get("llmRequest", {}),
        payload.get("usage", {}),
        payload.get("response", {}),
        payload.get("metadata", {}),
    ):
        if not isinstance(container, dict):
            continue
        for key in keys:
            value = container.get(key)
            if isinstance(value, str) and _MODEL_ID.match(value):
                return value
    return ""


def _payload_model(payload: dict) -> str:
    payload_hint = _payload_model_hint(payload)
    if payload_hint:
        return payload_hint

    # Check AGY environment variable
    env_model = os.environ.get("ANTIGRAVITY_MODEL", "")
    if env_model and _MODEL_ID.match(env_model):
        return env_model
    # Try reading current model from AGY settings.json
    try:
        settings_path = pathlib.Path.home() / ".gemini/antigravity-cli/settings.json"
        if settings_path.is_file():
            settings = json.loads(settings_path.read_text(encoding="utf-8"))
            if isinstance(settings, dict):
                m = settings.get("model", "")
                if isinstance(m, str) and _MODEL_ID.match(m):
                    return m
    except Exception:
        pass
    return "antigravity-unknown"


def _non_negative_int(value) -> int:
    try:
        parsed = int(value)
    except Exception:
        return 0
    return parsed if parsed > 0 else 0


_INPUT_TOKEN_KEYS = (
    "input_tokens",
    "inputTokens",
    "prompt_tokens",
    "promptTokens",
    "promptTokenCount",
    "prompt_token_count",
)
_TOKENS_INPUT_KEYS = (
    "input",
    "input_token_count",
    "inputTokenCount",
)
_OUTPUT_TOKEN_KEYS = (
    "output_tokens",
    "outputTokens",
    "completion_tokens",
    "completionTokens",
    "candidatesTokenCount",
    "candidates_token_count",
    "completion_token_count",
    "thoughts_token_count",
    "thoughtsTokenCount",
)
_TOKENS_OUTPUT_KEYS = (
    "output",
    "output_token_count",
    "outputTokenCount",
)
_TOTAL_TOKEN_KEYS = (
    "total_tokens",
    "totalTokens",
    "totalTokenCount",
    "total_token_count",
)
_CACHE_INPUT_KEYS = (
    "cached_content_token_count",
    "cachedContentTokenCount",
    "cache_read_input_tokens",
    "cacheReadInputTokens",
)


def _add_container(containers: list[dict], candidate) -> None:
    if isinstance(candidate, dict):
        containers.append(candidate)


def _token_containers(payload: dict) -> list[dict]:
    containers: list[dict] = []
    _add_container(containers, payload)
    for key in (
        "spill_token_usage",
        "spillTokenUsage",
        "token_usage",
        "tokenUsage",
        "usage",
        "usageMetadata",
        "usage_metadata",
        "tokens",
        "response",
        "llm_response",
        "llmResponse",
    ):
        _add_container(containers, payload.get(key))

    for key in ("response", "llm_response", "llmResponse"):
        nested = payload.get(key)
        if isinstance(nested, dict):
            _add_container(containers, nested.get("usage"))
            _add_container(containers, nested.get("usageMetadata"))
            _add_container(containers, nested.get("usage_metadata"))

    return containers


def _first_positive_int(containers: list[dict], keys: tuple[str, ...]) -> int:
    for container in containers:
        for key in keys:
            value = _non_negative_int(container.get(key))
            if value > 0:
                return value
    return 0


def _has_any_int_field(containers: list[dict], keys: tuple[str, ...]) -> bool:
    return any(_non_negative_int(container.get(key)) > 0 for container in containers for key in keys)


def _has_tokens_alias_input_output(payload: dict) -> bool:
    tokens = payload.get("tokens")
    if not isinstance(tokens, dict):
        return False
    return _has_any_int_field([tokens], _TOKENS_INPUT_KEYS) or _has_any_int_field([tokens], _TOKENS_OUTPUT_KEYS)


def _payload_token_counts(payload: dict) -> tuple[int, int, int, bool]:
    containers = _token_containers(payload)
    input_tokens = _first_positive_int(containers, _INPUT_TOKEN_KEYS)
    output_tokens = _first_positive_int(containers, _OUTPUT_TOKEN_KEYS)
    cache_tokens = _first_positive_int(containers, _CACHE_INPUT_KEYS)
    tokens = payload.get("tokens")
    if isinstance(tokens, dict):
        input_tokens = input_tokens or _first_positive_int([tokens], _TOKENS_INPUT_KEYS)
        output_tokens = output_tokens or _first_positive_int([tokens], _TOKENS_OUTPUT_KEYS)
    # cached content tokens count as input for billing purposes
    if cache_tokens > 0 and input_tokens == 0:
        input_tokens = cache_tokens
    total = input_tokens + output_tokens

    if total > 0:
        return input_tokens, output_tokens, total, False

    total = _first_positive_int(containers, _TOTAL_TOKEN_KEYS)
    if total > 0:
        return total, 0, total, True

    return 0, 0, 0, False


def _payload_span_hint(payload: dict, total_only: bool) -> str:
    id_keys = (
        "span_id",
        "spanId",
        "event_id",
        "eventId",
        "invocation_id",
        "invocationId",
        "turn_id",
        "turnId",
        "request_id",
        "requestId",
    )
    time_keys = ("created_at", "createdAt", "timestamp")
    for container in _token_containers(payload):
        for key in id_keys:
            value = container.get(key)
            if isinstance(value, str) and _OPAQUE_ID.match(value):
                return value
        for key in time_keys:
            value = container.get(key)
            if isinstance(value, str) and 6 <= len(value) <= 64:
                return "time-" + hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]

    return uuid.uuid4().hex[:12] if total_only else ""


def _consume_label_file() -> None:
    if not _USED_LABEL_FILE:
        return
    try:
        LABEL_FILE.unlink()
    except Exception:
        pass


def _read_stdin_nonblocking() -> str:
    try:
        ready, _, _ = select.select([sys.stdin], [], [], 1.0)
        if ready:
            data = os.read(sys.stdin.fileno(), 65536)
            return data.decode("utf-8")
    except Exception:
        pass
    return ""


def _clear_diagnostic() -> None:
    try:
        for name in (MISMATCH_DIAGNOSTIC_FILE_NAME, LEGACY_DIAGNOSTIC_FILE_NAME):
            final_path = DIAGNOSTICS_DIR / name
            if final_path.is_file():
                final_path.unlink()
    except Exception:
        pass


def main() -> None:
    raw_payload = _read_stdin_nonblocking()

    if not raw_payload.strip():
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "empty_stdin_hook_call",
            "empty_stdin",
            meaning="AGY invoked the hook for a lifecycle or tool step that did not expose token usage payload on stdin.",
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

    input_tokens, output_tokens, total, total_only = _payload_token_counts(payload)

    if total <= 0:
        _write_diagnostic_file(
            EMPTY_DIAGNOSTIC_FILE_NAME,
            "no_usage_hook_call",
            "no_token_usage_payload",
            payload,
            meaning="AGY invoked the hook with a structured payload that did not expose exact token usage. This can be a normal lifecycle, tool, or model-adjacent hook call.",
        )
        return

    model = _payload_model(payload)
    env_conv_id = os.environ.get("ANTIGRAVITY_CONVERSATION_ID", "")
    session_id = (
        env_conv_id
        or str(payload.get("session_id", payload.get("conversationId", "")))
    )
    run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])
    span_hint = _payload_span_hint(payload, total_only)
    span_id = _stable_span_id(run_id, model, str(input_tokens), str(output_tokens), str(total), span_hint)
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

    task_type = _safe_label(
        payload,
        ("task_type", "taskType"),
        ("SPILL_TOKEN_USAGE_TASK_TYPE", "SPILL_WORKFLOW_TASK_TYPE"),
        "uncategorized",
    )
    stage = _safe_label(
        payload,
        ("stage", "workflow_stage", "workflowStage"),
        ("SPILL_TOKEN_USAGE_STAGE", "SPILL_WORKFLOW_STAGE"),
        "summarize",
    )

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
            "generated_output": 0 if total_only else output_tokens,
            "unknown": total if total_only else input_tokens,
        },
        "latency_ms": 0,
        "created_at": now,
        "sync_mode": "local_only",
    }

    _enqueue_event(event)
    _consume_label_file()
    _clear_diagnostic()
    _write_success_diagnostic(event)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
