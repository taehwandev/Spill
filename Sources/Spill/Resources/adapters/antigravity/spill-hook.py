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
    if tool not in ("", "unknown", "antigravity"):
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


def _stable_span_id(*parts: str) -> str:
    source = ":".join(parts)
    return "span-" + hashlib.sha256(source.encode("utf-8")).hexdigest()[:12]


def _payload_model(payload: dict) -> str:
    keys = ("model", "model_name", "modelName", "model_id", "modelId", "modelVersion")
    for container in (
        payload,
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
    return "antigravity-unknown"


def _consume_label_file() -> None:
    if not _USED_LABEL_FILE:
        return
    try:
        LABEL_FILE.unlink()
    except Exception:
        pass


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

    model = _payload_model(payload)

    session_id = str(payload.get("session_id", payload.get("conversationId", "")))
    run_id = _opaque(session_id, "run-" + uuid.uuid4().hex[:12])
    span_id = _stable_span_id(run_id, model, str(input_tokens), str(output_tokens), str(total))
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
            "generated_output": output_tokens,
            "unknown": input_tokens,
        },
        "latency_ms": 0,
        "created_at": now,
        "sync_mode": "local_only",
    }

    _enqueue_event(event)
    _consume_label_file()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
