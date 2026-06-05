#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${SPILL_TOKEN_METERING_BASE_URL:-https://spill.thdev.app/token-metering}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-token-metering.XXXXXX")"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

download() {
    local remote_path="$1"
    local local_path="$TMP_DIR/$remote_path"

    mkdir -p "$(dirname "$local_path")"
    curl -fsSL "$BASE_URL/$remote_path" -o "$local_path"
}

require_node() {
    if ! command -v node >/dev/null 2>&1; then
        echo "Spill token metering setup requires Node.js to run the local setup helper." >&2
        exit 127
    fi
}

require_node

download "adapters/setup/spill-token-metering-setup.mjs"
download "adapters/codex/spill-importer.mjs"
download "adapters/claude-code/spill-hook.py"
download "adapters/antigravity/spill-hook.py"
download "adapters/openai/spill-adapter.py"

node "$TMP_DIR/adapters/setup/spill-token-metering-setup.mjs" \
    --apply \
    --include codex,claude,antigravity,openai \
    --source-root "$TMP_DIR/adapters" \
    --json \
    "$@"
