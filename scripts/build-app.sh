#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env.local" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ROOT_DIR/.env.local"
    set +a
fi

APP_DIR="$ROOT_DIR/.build/Spill.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
BUNDLE_ID="${SPILL_BUNDLE_ID:-dev.spill.Spill}"
DEFAULT_VERSION="$(date -u +%G.%V.1)"
VERSION="${SPILL_VERSION:-$DEFAULT_VERSION}"
BUILD_NUMBER="${SPILL_BUILD:-${VERSION##*.}}"
SIGN_IDENTITY="${SPILL_SIGN_IDENTITY:--}"
APTABASE_APP_KEY="${SPILL_APTABASE_APP_KEY:-}"
APTABASE_INFO_PLIST_ENTRY=""
DEFAULT_SPARKLE_PUBLIC_ED_KEY="Ct1877nZCozc18GRWu66vBaTpuAuj1RTxzKlyH6WvpA="
SPARKLE_PUBLIC_ED_KEY="${SPILL_SPARKLE_PUBLIC_ED_KEY:-$DEFAULT_SPARKLE_PUBLIC_ED_KEY}"
SPARKLE_FEED_URL="${SPILL_SPARKLE_FEED_URL:-https://github.com/taehwandev/Spill/releases/latest/download/appcast.xml}"
SPARKLE_INFO_PLIST_ENTRY=""
ENTITLEMENTS_PATH="$ROOT_DIR/.build/Spill.entitlements"

if [[ "${SPILL_DISABLE_SPARKLE:-0}" == "1" ]]; then
    SPARKLE_PUBLIC_ED_KEY=""
fi

sign_sparkle_framework() {
    local sparkle_version_dir="$FRAMEWORKS_DIR/Sparkle.framework/Versions/B"

    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/Autoupdate"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/Updater.app"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/XPCServices/Downloader.xpc"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/XPCServices/Installer.xpc"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$FRAMEWORKS_DIR/Sparkle.framework"
}

if [[ -n "$APTABASE_APP_KEY" ]]; then
    if [[ ! "$APTABASE_APP_KEY" =~ ^A-[A-Z]{2}-[0-9]+$ ]]; then
        echo "SPILL_APTABASE_APP_KEY must look like A-US-1234567890 or A-EU-1234567890." >&2
        exit 2
    fi

    APTABASE_INFO_PLIST_ENTRY="    <key>SPILLAptabaseAppKey</key>
    <string>$APTABASE_APP_KEY</string>"
fi

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    SPARKLE_INFO_PLIST_ENTRY="    <key>SUFeedURL</key>
    <string>$SPARKLE_FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_ED_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <false/>
    <key>SUAutomaticallyUpdate</key>
    <false/>"
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    cat > "$ENTITLEMENTS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
PLIST
else
    rm -f "$ENTITLEMENTS_PATH"
fi

swift build -c release --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$ROOT_DIR/.build/release/Spill" "$MACOS_DIR/Spill"

SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build/artifacts/sparkle" -path "*/Sparkle.framework" -type d -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle.framework was not found after swift build." >&2
    exit 2
fi

ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
if ! otool -l "$MACOS_DIR/Spill" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/Spill"
fi

ICONSET_DIR="$CONTENTS_DIR/AppIcon.iconset"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICONSET_DIR" "$ROOT_DIR/docs/assets/spill-icon.png"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Spill</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>Spill</string>
    <key>CFBundleDisplayName</key>
    <string>Spill</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Spill contributors</string>
$APTABASE_INFO_PLIST_ENTRY
$SPARKLE_INFO_PLIST_ENTRY
</dict>
</plist>
PLIST

sign_sparkle_framework

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign \
        --force \
        --options runtime \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$ENTITLEMENTS_PATH" \
        --requirements "=designated => identifier \"$BUNDLE_ID\"" \
        "$APP_DIR"
else
    codesign \
        --force \
        --options runtime \
        --sign "$SIGN_IDENTITY" \
        --requirements "=designated => identifier \"$BUNDLE_ID\"" \
        "$APP_DIR"
fi

echo "Built $APP_DIR"
