#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Spill"
DOWNLOAD_URL="${SPILL_DOWNLOAD_URL:-https://github.com/taehwandev/Spill/releases/latest/download/Spill-macos.zip}"
INSTALL_DIR="${SPILL_INSTALL_DIR:-/Applications}"
OPEN_AFTER_INSTALL="${SPILL_OPEN_AFTER_INSTALL:-1}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spill-install.XXXXXX")"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

ARCHIVE_PATH="$TMP_DIR/Spill-macos.zip"
EXTRACT_DIR="$TMP_DIR/extract"
SOURCE_APP="$EXTRACT_DIR/$APP_NAME.app"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"

echo "Downloading $APP_NAME..."
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

if [[ "$OPEN_AFTER_INSTALL" != "0" ]]; then
    open "$TARGET_APP"
fi
