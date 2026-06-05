#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env.local" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ROOT_DIR/.env.local"
    set +a
fi

SOURCE_DIR="$ROOT_DIR/docs"
OUTPUT_DIR="${SPILL_DOCS_OUTPUT_DIR:-$ROOT_DIR/.build/docs}"
WEB_APTABASE_APP_KEY="${SPILL_WEB_APTABASE_APP_KEY:-${SPILL_APTABASE_APP_KEY:-}}"
INSTALLER_APTABASE_APP_KEY="${SPILL_INSTALLER_APTABASE_APP_KEY:-${SPILL_APTABASE_APP_KEY:-}}"

validate_app_key() {
    local name="$1"
    local value="$2"

    if [[ -n "$value" && ! "$value" =~ ^A-[A-Z]{2}-[0-9]+$ ]]; then
        echo "$name must look like A-US-1234567890 or A-EU-1234567890." >&2
        exit 2
    fi
}

replace_placeholder() {
    local file="$1"
    local placeholder="$2"
    local value="$3"

    if [[ -n "$value" ]]; then
        PLACEHOLDER="$placeholder" REPLACEMENT_VALUE="$value" \
            perl -0pi -e 's/\Q$ENV{PLACEHOLDER}\E/$ENV{REPLACEMENT_VALUE}/g' "$file"
    fi
}

validate_app_key "SPILL_WEB_APTABASE_APP_KEY" "$WEB_APTABASE_APP_KEY"
validate_app_key "SPILL_INSTALLER_APTABASE_APP_KEY" "$INSTALLER_APTABASE_APP_KEY"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$SOURCE_DIR"/. "$OUTPUT_DIR"/

mkdir -p "$OUTPUT_DIR/token-metering/adapters"
cp -R "$ROOT_DIR/Sources/Spill/Resources/adapters"/. "$OUTPUT_DIR/token-metering/adapters"/
cp "$ROOT_DIR/scripts/spill-token-metering-setup.mjs" "$OUTPUT_DIR/token-metering/adapters/setup/spill-token-metering-setup.mjs"
cp "$ROOT_DIR/scripts/spill-codex-session-importer.mjs" "$OUTPUT_DIR/token-metering/adapters/codex/spill-importer.mjs"

replace_placeholder "$OUTPUT_DIR/index.html" "__SPILL_WEB_APTABASE_APP_KEY__" "$WEB_APTABASE_APP_KEY"

replace_placeholder "$OUTPUT_DIR/install.sh" "__SPILL_INSTALLER_APTABASE_APP_KEY__" "$INSTALLER_APTABASE_APP_KEY"

echo "Prepared docs at $OUTPUT_DIR"
