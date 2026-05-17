#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_VERSION="$(date -u +%G.%V.1)"
VERSION="${SPILL_VERSION:-$DEFAULT_VERSION}"
BUILD_NUMBER="${SPILL_BUILD:-1}"
APP_DIR="$ROOT_DIR/.build/Spill.app"
ARTIFACTS_DIR="$ROOT_DIR/.build/release-artifacts"
ZIP_PATH="$ARTIFACTS_DIR/Spill-$VERSION-macos.zip"
DMG_PATH="$ARTIFACTS_DIR/Spill-$VERSION-macos.dmg"
UPDATE_MANIFEST_PATH="$ARTIFACTS_DIR/update.json"
DMG_ROOT="$ARTIFACTS_DIR/dmg-root"
NOTARY_PROFILE="${SPILL_NOTARY_KEYCHAIN_PROFILE:-}"
DOWNLOAD_BASE_URL="${SPILL_DOWNLOAD_BASE_URL:-https://github.com/taehwankwon/Spill/releases/latest/download}"
RELEASE_NOTES_URL="${SPILL_RELEASE_NOTES_URL:-https://github.com/taehwankwon/Spill/releases/latest}"
PUBLISHED_AT="${SPILL_PUBLISHED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

if [[ -n "$NOTARY_PROFILE" && "${SPILL_SIGN_IDENTITY:--}" == "-" ]]; then
    echo "SPILL_SIGN_IDENTITY must be a Developer ID Application identity when notarizing." >&2
    exit 2
fi

"$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$ARTIFACTS_DIR"
rm -rf "$DMG_ROOT"
rm -f "$ZIP_PATH" "$DMG_PATH" "$UPDATE_MANIFEST_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_ZIP="$ARTIFACTS_DIR/Spill-$VERSION-notary.zip"
    rm -f "$NOTARY_ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_DIR"
    rm -f "$NOTARY_ZIP"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

mkdir -p "$DMG_ROOT"
ditto "$APP_DIR" "$DMG_ROOT/Spill.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "Spill" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_ROOT"

if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
fi

cat > "$UPDATE_MANIFEST_PATH" <<JSON
{
  "latestVersion": "$VERSION",
  "build": "$BUILD_NUMBER",
  "minimumMacOS": "14.0",
  "downloadURL": "$DOWNLOAD_BASE_URL/Spill-macos.dmg",
  "releaseNotesURL": "$RELEASE_NOTES_URL",
  "publishedAt": "$PUBLISHED_AT"
}
JSON

echo "Built release artifacts:"
echo "$ZIP_PATH"
echo "$DMG_PATH"
echo "$UPDATE_MANIFEST_PATH"
