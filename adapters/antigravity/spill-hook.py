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
DIAGNOSTIC_FILE_NAME = "antigravity-latest.json"
_DIAGNOSTIC_PRIORITIES = {
    "empty_stdin": 10,
    "stdin_unavailable": 20,
    "invalid_json": 30,
    "non_object_payload": 30,
    "missing_exact_token_usage": 100,
}
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


def _write_diagnostic(reason: str, payload: dict = None) -> None:
    if os.environ.get("SPILL_TOKEN_USAGE_DISABLE_DIAGNOSTICS") == "1":
        return

    diagnostic = {
        "schema_version": 1,
        "ai_tool": "antigravity",
        "kind": "runtime_payload_mismatch",
        "reason": reason,
        "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z"),
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

    try:
        DIAGNOSTICS_DIR.mkdir(parents=True, exist_ok=True)
        final_path = DIAGNOSTICS_DIR / DIAGNOSTIC_FILE_NAME
        if _existing_diagnostic_priority(final_path) > _diagnostic_priority(reason):
            return
        temporary_path = DIAGNOSTICS_DIR / ".antigravity-latest.tmp"
        with open(temporary_path, "w") as f:
            f.write(json.dumps(diagnostic, separators=(",", ":")))
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, final_path)
    except Exception:
        pass


def _diagnostic_priority(reason: str) -> int:
    return _DIAGNOSTIC_PRIORITIES.get(reason, 50)


def _existing_diagnostic_priority(path: pathlib.Path) -> int:
    try:
        data = json.loads(path.read_text())
    except Exception:
        return 0
    if not isinstance(data, dict):
        return 0
    reason = data.get("reason")
    return _diagnostic_priority(reason) if isinstance(reason, str) else 0


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
        "has_model_hint": _payload_model(payload) != "antigravity-unknown",
        "has_opaque_run_hint": any(isinstance(payload.get(key), str) for key in ("session_id", "conversationId")),
    }


def _stable_span_id(*parts: str) -> str:
    source = ":".join(parts)
    return "span-" + hashlib.sha256(source.encode("utf-8")).hexdigest()[:12]


def _payload_model(payload: dict) -> str:
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


SESSION_STATE_DIR = pathlib.Path(
    os.environ.get(
        "SPILL_TOKEN_USAGE_SESSION_STATE_DIR",
        pathlib.Path.home() / "Library/Application Support/Spill/token-metering/session-state",
    )
)


def _load_session_state(run_id: str) -> tuple[int, int]:
    """Return (prev_input, prev_output) recorded for this run, or (0, 0)."""
    state_path = SESSION_STATE_DIR / f"{run_id}.json"
    try:
        data = json.loads(state_path.read_text())
        if isinstance(data, dict):
            return int(data.get("input", 0)), int(data.get("output", 0))
    except Exception:
        pass
    return 0, 0


def _save_session_state(run_id: str, input_tokens: int, output_tokens: int) -> None:
    try:
        SESSION_STATE_DIR.mkdir(parents=True, exist_ok=True)
        state_path = SESSION_STATE_DIR / f"{run_id}.json"
        tmp_path = SESSION_STATE_DIR / f".{run_id}.tmp"
        tmp_path.write_text(json.dumps({"input": input_tokens, "output": output_tokens}))
        os.replace(tmp_path, state_path)
    except Exception:
        pass


def _normalize_token_type(raw: str) -> str:
    val = str(raw).replace("-", "_").replace(" ", "_").lower()
    if val in {"input", "input_token", "input_tokens"}:
        return "input"
    if val in {"output", "output_token", "output_tokens"}:
        return "output"
    if val in {"cache", "cached", "cached_content", "cache_read"}:
        return "cache"
    if val in {"thought", "thoughts", "reasoning"}:
        return "thought"
    if val in {"tool", "tools"}:
        return "tool"
    return "unknown"


def _parse_otel_telemetry_log(telemetry_path: pathlib.Path) -> dict:
    """Parse an OpenTelemetry JSONL telemetry log (Gemini CLI or Antigravity format).

    Returns a dict keyed by session_id, each containing model and token buckets.
    """
    if not telemetry_path.is_file():
        return {}

    try:
        content = telemetry_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return {}

    decoder = json.JSONDecoder()
    index = 0
    length = len(content)
    sessions: dict = {}

    while index < length:
        while index < length and content[index].isspace():
            index += 1
        if index >= length:
            break
        if content[index] != "{":
            next_obj = content.find("{", index + 1)
            if next_obj < 0:
                break
            index = next_obj
        try:
            payload, end = decoder.raw_decode(content, index)
            index = end
        except json.JSONDecodeError:
            next_obj = content.find("{", index + 1)
            if next_obj < 0:
                break
            index = next_obj
            continue

        # Support both scopeMetrics (OTel) and resourceMetrics > scopeMetrics wrappers
        scope_metrics_list = payload.get("scopeMetrics") or []
        for resource_metric in payload.get("resourceMetrics") or []:
            if isinstance(resource_metric, dict):
                scope_metrics_list = scope_metrics_list + (resource_metric.get("scopeMetrics") or [])

        for scope in scope_metrics_list:
            if not isinstance(scope, dict):
                continue
            for metric in scope.get("metrics") or []:
                desc = metric.get("descriptor") or {}
                m_name = desc.get("name") or metric.get("name") or ""
                if m_name not in {
                    "gemini_cli.token.usage",
                    "gen_ai.client.token.usage",
                    "antigravity.token.usage",
                    "agy.token.usage",
                }:
                    continue
                for point in metric.get("dataPoints") or []:
                    if not isinstance(point, dict):
                        continue
                    attrs = point.get("attributes") or {}
                    session_id = (
                        attrs.get("session.id")
                        or attrs.get("session_id")
                        or attrs.get("conversation.id")
                        or attrs.get("conversation_id")
                    )
                    if not session_id:
                        continue

                    raw_type = (
                        attrs.get("type")
                        or attrs.get("gen_ai.token.type")
                        or attrs.get("token.type")
                        or ""
                    )
                    token_type = _normalize_token_type(raw_type)
                    if token_type == "unknown":
                        continue

                    model = (
                        attrs.get("model")
                        or attrs.get("gen_ai.response.model")
                        or attrs.get("gen_ai.request.model")
                        or "unknown"
                    )
                    val = point.get("value")
                    if val is None:
                        continue
                    try:
                        val = int(val)
                    except (ValueError, TypeError):
                        continue

                    end_time_raw = point.get("endTime") or point.get("startTime")
                    end_time = 0.0
                    if isinstance(end_time_raw, list) and len(end_time_raw) >= 1:
                        end_time = float(end_time_raw[0]) + (float(end_time_raw[1]) / 1e9 if len(end_time_raw) > 1 else 0.0)

                    if session_id not in sessions:
                        sessions[session_id] = {
                            "session_id": session_id,
                            "model": model,
                            "last_time": end_time,
                            "tokens": {}
                        }

                    sess = sessions[session_id]
                    if end_time >= sess["last_time"]:
                        sess["last_time"] = end_time
                        sess["tokens"][token_type] = val
                        if model != "unknown":
                            sess["model"] = model

    return sessions


def _parse_telemetry_log() -> dict:
    """Try antigravity-telemetry.log first, then fall back to gemini telemetry.log."""
    agt_path = pathlib.Path.home() / ".agentcat/gemini/antigravity-telemetry.log"
    sessions = _parse_otel_telemetry_log(agt_path)
    if sessions:
        return sessions
    # Legacy fallback for gemini-cli telemetry
    gem_path = pathlib.Path.home() / ".agentcat/gemini/telemetry.log"
    return _parse_otel_telemetry_log(gem_path)


def main() -> None:
    raw_payload = _read_stdin_nonblocking()

    # DEBUG DUMP
    try:
        with open("/tmp/spill-hook-debug.log", "a") as f:
            f.write(f"\n--- Hook Fired: {datetime.datetime.now()} ---\n")
            f.write(f"Arguments: {sys.argv}\n")
            f.write(f"Environment keys: {list(os.environ.keys())}\n")
            f.write(f"Environment SPILL_ keys: {{k: v for k, v in os.environ.items() if k.startswith('SPILL')}}\n")
            f.write(f"Raw stdin length: {len(raw_payload)}\n")
            if raw_payload:
                f.write(f"Raw stdin: {raw_payload[:1000]}\n")
    except Exception as e:
        pass

    # Try parsing stdin if it is not empty
    payload = None
    if raw_payload.strip():
        try:
            payload = json.loads(raw_payload)
        except Exception:
            pass

    if payload and isinstance(payload, dict):
        input_tokens, output_tokens, total, total_only = _payload_token_counts(payload)

        if total > 0:
            model = _payload_model(payload)
            # Prefer ANTIGRAVITY_CONVERSATION_ID env var as a stable opaque session key
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
            return
        else:
            _write_diagnostic("missing_exact_token_usage", payload)
            return

    # Fallback to parsing telemetry.log when stdin is empty/invalid
    sessions = _parse_telemetry_log()
    if not sessions:
        _write_diagnostic("empty_stdin")
        return

    events_emitted = 0
    for session_id, sess in sessions.items():
        raw_input = sess["tokens"].get("input", 0)
        raw_output = sess["tokens"].get("output", 0)
        raw_thought = sess["tokens"].get("thought", 0)
        raw_tool = sess["tokens"].get("tool", 0)
        raw_cache = sess["tokens"].get("cache", 0)

        session_input = raw_input + raw_cache
        session_output = raw_output + raw_thought + raw_tool

        if session_input == 0 and session_output == 0:
            continue

        model = sess["model"]
        if not _MODEL_ID.match(model):
            model = "gemini-unknown"

        run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])
        prev_input, prev_output = _load_session_state(run_id)

        delta_input = session_input - prev_input
        delta_output = session_output - prev_output

        if delta_input <= 0 and delta_output <= 0:
            if prev_input == 0 and prev_output == 0:
                _save_session_state(run_id, session_input, session_output)
            continue

        _save_session_state(run_id, session_input, session_output)

        span_id = _stable_span_id(run_id, model, str(session_input), str(session_output))
        now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

        task_type = _safe_label(
            {},
            ("task_type", "taskType"),
            ("SPILL_TOKEN_USAGE_TASK_TYPE", "SPILL_WORKFLOW_TASK_TYPE"),
            "uncategorized",
        )
        stage = _safe_label(
            {},
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
            "input_tokens": delta_input,
            "output_tokens": delta_output,
            "total_tokens": delta_input + delta_output,
            "token_breakdown": {
                "system": 0,
                "user": 0,
                "history": raw_cache,
                "repo_context": 0,
                "tool_output": raw_tool,
                "generated_output": delta_output,
                "unknown": delta_input,
            },
            "latency_ms": 0,
            "created_at": now,
            "sync_mode": "local_only",
        }

        _enqueue_event(event)
        events_emitted += 1

    if events_emitted > 0:
        _consume_label_file()
    else:
        _write_diagnostic("empty_stdin")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
