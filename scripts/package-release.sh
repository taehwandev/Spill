#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_VERSION="$(date -u +%G.%V.1)"
VERSION="${SPILL_VERSION:-$DEFAULT_VERSION}"
BUILD_NUMBER="${SPILL_BUILD:-${VERSION##*.}}"
APP_DIR="$ROOT_DIR/.build/Spill.app"
ARTIFACTS_DIR="$ROOT_DIR/.build/release-artifacts"
ZIP_PATH="$ARTIFACTS_DIR/Spill-$VERSION-macos.zip"
DMG_PATH="$ARTIFACTS_DIR/Spill-$VERSION-macos.dmg"
PKG_PATH="$ARTIFACTS_DIR/Spill-$VERSION-macos.pkg"
STABLE_ZIP_PATH="$ARTIFACTS_DIR/Spill-macos.zip"
STABLE_DMG_PATH="$ARTIFACTS_DIR/Spill-macos.dmg"
STABLE_PKG_PATH="$ARTIFACTS_DIR/Spill-macos.pkg"
UPDATE_MANIFEST_PATH="$ARTIFACTS_DIR/update.json"
APPCAST_PATH="$ARTIFACTS_DIR/appcast.xml"
CHECKSUMS_PATH="$ARTIFACTS_DIR/checksums.txt"
DMG_ROOT="$ARTIFACTS_DIR/dmg-root"
APPCAST_ARCHIVE_DIR="$ARTIFACTS_DIR/appcast-input"
INSTALLER_SIGN_IDENTITY="${SPILL_INSTALLER_SIGN_IDENTITY:-}"
BUNDLE_ID="${SPILL_BUNDLE_ID:-dev.spill.Spill}"
SKIP_BUILD="${SPILL_SKIP_BUILD:-false}"
DOWNLOAD_BASE_URL="${SPILL_DOWNLOAD_BASE_URL:-https://github.com/taehwandev/Spill/releases/latest/download}"
RELEASE_NOTES_URL="${SPILL_RELEASE_NOTES_URL:-https://github.com/taehwandev/Spill/releases/latest}"
PUBLISHED_AT="${SPILL_PUBLISHED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
SPARKLE_PRIVATE_KEY_FILE="${SPILL_SPARKLE_PRIVATE_KEY_FILE:-}"
SPARKLE_PUBLIC_ED_KEY="${SPILL_SPARKLE_PUBLIC_ED_KEY:-}"
SPARKLE_GENERATE_APPCAST="${SPILL_SPARKLE_GENERATE_APPCAST:-}"
SPARKLE_DOWNLOAD_URL_PREFIX="${SPILL_SPARKLE_DOWNLOAD_URL_PREFIX:-$DOWNLOAD_BASE_URL}"

if [[ -n "$SPARKLE_DOWNLOAD_URL_PREFIX" && "$SPARKLE_DOWNLOAD_URL_PREFIX" != */ ]]; then
    SPARKLE_DOWNLOAD_URL_PREFIX="$SPARKLE_DOWNLOAD_URL_PREFIX/"
fi

if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "SPILL_SPARKLE_PUBLIC_ED_KEY is required when SPILL_SPARKLE_PRIVATE_KEY_FILE is set." >&2
    exit 2
fi

if [[ "$SKIP_BUILD" != "1" && "$SKIP_BUILD" != "true" ]]; then
    "$ROOT_DIR/scripts/build-app.sh"
fi

mkdir -p "$ARTIFACTS_DIR"
rm -rf "$DMG_ROOT" "$APPCAST_ARCHIVE_DIR"
rm -f "$ARTIFACTS_DIR"/Spill-*-macos.zip
rm -f "$ARTIFACTS_DIR"/Spill-*-macos.dmg
rm -f "$ARTIFACTS_DIR"/Spill-*-macos.pkg
rm -f "$STABLE_ZIP_PATH" "$STABLE_DMG_PATH" "$STABLE_PKG_PATH" "$UPDATE_MANIFEST_PATH" "$APPCAST_PATH" "$CHECKSUMS_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

mkdir -p "$DMG_ROOT"
ditto "$APP_DIR" "$DMG_ROOT/Spill.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "Spill" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_ROOT"

HAS_INSTALLER_PACKAGE=false
if [[ -n "$INSTALLER_SIGN_IDENTITY" ]]; then
    pkgbuild \
        --component "$APP_DIR" \
        --install-location "/Applications" \
        --identifier "$BUNDLE_ID" \
        --version "$VERSION" \
        --sign "$INSTALLER_SIGN_IDENTITY" \
        "$PKG_PATH"

    HAS_INSTALLER_PACKAGE=true
fi

cp "$ZIP_PATH" "$STABLE_ZIP_PATH"
cp "$DMG_PATH" "$STABLE_DMG_PATH"
if [[ "$HAS_INSTALLER_PACKAGE" == "true" ]]; then
    cp "$PKG_PATH" "$STABLE_PKG_PATH"
fi

if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    if [[ "$SPARKLE_PRIVATE_KEY_FILE" != "-" && ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
        echo "SPILL_SPARKLE_PRIVATE_KEY_FILE does not exist: $SPARKLE_PRIVATE_KEY_FILE" >&2
        exit 2
    fi

    if [[ -z "$SPARKLE_GENERATE_APPCAST" ]]; then
        SPARKLE_GENERATE_APPCAST="$(find "$ROOT_DIR/.build/artifacts/sparkle" -path "*/bin/generate_appcast" -type f -print -quit)"
    fi

    if [[ -z "$SPARKLE_GENERATE_APPCAST" || ! -x "$SPARKLE_GENERATE_APPCAST" ]]; then
        echo "Sparkle generate_appcast was not found. Set SPILL_SPARKLE_GENERATE_APPCAST." >&2
        exit 2
    fi

    mkdir -p "$APPCAST_ARCHIVE_DIR"
    cp "$ZIP_PATH" "$APPCAST_ARCHIVE_DIR/"

    "$SPARKLE_GENERATE_APPCAST" \
        --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" \
        --download-url-prefix "$SPARKLE_DOWNLOAD_URL_PREFIX" \
        --full-release-notes-url "$RELEASE_NOTES_URL" \
        --maximum-versions 1 \
        "$APPCAST_ARCHIVE_DIR"

    cp "$APPCAST_ARCHIVE_DIR/appcast.xml" "$APPCAST_PATH"
fi

{
    echo "{"
    echo "  \"latestVersion\": \"$VERSION\","
    echo "  \"build\": \"$BUILD_NUMBER\","
    echo "  \"minimumMacOS\": \"14.0\","
    echo "  \"downloadURL\": \"$DOWNLOAD_BASE_URL/Spill-macos.dmg\","
    if [[ "$HAS_INSTALLER_PACKAGE" == "true" ]]; then
        echo "  \"packageURL\": \"$DOWNLOAD_BASE_URL/Spill-macos.pkg\","
    fi
    echo "  \"releaseNotesURL\": \"$RELEASE_NOTES_URL\","
    echo "  \"publishedAt\": \"$PUBLISHED_AT\""
    echo "}"
} > "$UPDATE_MANIFEST_PATH"

(
    cd "$ARTIFACTS_DIR"
    checksum_files=(
        "Spill-$VERSION-macos.dmg"
        "Spill-$VERSION-macos.zip"
        "Spill-macos.dmg"
        "Spill-macos.zip"
    )
    if [[ "$HAS_INSTALLER_PACKAGE" == "true" ]]; then
        checksum_files+=(
            "Spill-$VERSION-macos.pkg"
            "Spill-macos.pkg"
        )
    fi
    checksum_files+=("update.json")
    if [[ -f "appcast.xml" ]]; then
        checksum_files+=("appcast.xml")
    fi
    shasum -a 256 "${checksum_files[@]}" > "$CHECKSUMS_PATH"
)

echo "Built release artifacts:"
echo "$ZIP_PATH"
echo "$DMG_PATH"
if [[ "$HAS_INSTALLER_PACKAGE" == "true" ]]; then
    echo "$PKG_PATH"
fi
echo "$STABLE_ZIP_PATH"
echo "$STABLE_DMG_PATH"
if [[ "$HAS_INSTALLER_PACKAGE" == "true" ]]; then
    echo "$STABLE_PKG_PATH"
fi
echo "$UPDATE_MANIFEST_PATH"
if [[ -f "$APPCAST_PATH" ]]; then
    echo "$APPCAST_PATH"
fi
echo "$CHECKSUMS_PATH"
