#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Spill"
DOWNLOAD_URL="${SPILL_DOWNLOAD_URL:-https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.zip}"
INSTALL_DIR="${SPILL_INSTALL_DIR:-/Applications}"
OPEN_AFTER_INSTALL="${SPILL_OPEN_AFTER_INSTALL:-1}"
APTABASE_APP_KEY="${SPILL_APTABASE_APP_KEY:-__SPILL_INSTALLER_APTABASE_APP_KEY__}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-install.XXXXXX")"
INSTALL_COMPLETE=0

case "$APTABASE_APP_KEY" in
    *-EU-*) APTABASE_HOST="https://eu.aptabase.com" ;;
    *) APTABASE_HOST="https://us.aptabase.com" ;;
esac

APTABASE_SESSION_ID="$(date -u +%s)$(awk 'BEGIN { srand(); printf "%08d", int(rand() * 100000000) }')"

track_install_event() {
    if [[ "${SPILL_TELEMETRY_DISABLED:-0}" == "1" ||
        -z "$APTABASE_APP_KEY" ||
        "$APTABASE_APP_KEY" == __*__ ]]
    then
        return
    fi

    case "$APTABASE_APP_KEY" in
        A-US-*|A-EU-*) ;;
        *) return ;;
    esac

    local event_name="$1"
    local phase="$2"
    local timestamp
    local payload

    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    payload="$(printf '[{"timestamp":"%s","sessionId":"%s","eventName":"%s","systemProps":{"locale":"unknown","osName":"macOS","osVersion":"unknown","deviceModel":"Mac","isDebug":false,"appVersion":"install-script","sdkVersion":"spill-install@1.0.0"},"props":{"source":"install_script","phase":"%s"}}]' "$timestamp" "$APTABASE_SESSION_ID" "$event_name" "$phase")"

    curl -fsS --max-time 2 \
        -H "Content-Type: application/json" \
        -H "App-Key: $APTABASE_APP_KEY" \
        -d "$payload" \
        "$APTABASE_HOST/api/v0/events" >/dev/null 2>&1 || true
}

cleanup() {
    local exit_status=$?
    if [[ "$INSTALL_COMPLETE" != "1" && "$exit_status" -ne 0 ]]; then
        track_install_event "install_failed" "exit_$exit_status"
    fi

    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

ARCHIVE_PATH="$TMP_DIR/Spill-macos.zip"
EXTRACT_DIR="$TMP_DIR/extract"
SOURCE_APP="$EXTRACT_DIR/$APP_NAME.app"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"

track_install_event "install_script_started" "started"

echo "Downloading $APP_NAME..."
track_install_event "install_archive_download_started" "download_started"
curl -fL --show-error --progress-bar "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"

echo "Extracting..."
mkdir -p "$EXTRACT_DIR"
ditto -x -k "$ARCHIVE_PATH" "$EXTRACT_DIR"

if [[ ! -d "$SOURCE_APP" ]]; then
    echo "Could not find $APP_NAME.app in the downloaded archive." >&2
    exit 2
fi

echo "Installing to $TARGET_APP..."
if mkdir -p "$INSTALL_DIR" 2>/dev/null && [[ -w "$INSTALL_DIR" ]]; then
    rm -rf "$TARGET_APP"
    ditto "$SOURCE_APP" "$TARGET_APP"
    xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
else
    sudo mkdir -p "$INSTALL_DIR"
    sudo rm -rf "$TARGET_APP"
    sudo ditto "$SOURCE_APP" "$TARGET_APP"
    sudo xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
fi

echo "Installed $APP_NAME."
INSTALL_COMPLETE=1
track_install_event "install_succeeded" "installed"

if [[ "$OPEN_AFTER_INSTALL" != "0" ]]; then
    open "$TARGET_APP"
fi
