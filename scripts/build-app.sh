#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${SPILL_SKIP_ENV_LOCAL:-0}" != "1" && -f "$ROOT_DIR/.env.local" ]]; then
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
HELPER_APP_NAME="Spill Token Dashboard.app"
HELPER_APP_DIR="$CONTENTS_DIR/Applications/$HELPER_APP_NAME"
HELPER_CONTENTS_DIR="$HELPER_APP_DIR/Contents"
HELPER_MACOS_DIR="$HELPER_CONTENTS_DIR/MacOS"
HELPER_RESOURCES_DIR="$HELPER_CONTENTS_DIR/Resources"
HELPER_FRAMEWORKS_DIR="$HELPER_CONTENTS_DIR/Frameworks"
BUNDLE_ID="${SPILL_BUNDLE_ID:-dev.spill.Spill}"
HELPER_BUNDLE_ID="${BUNDLE_ID}.TokenDashboard"
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
PRIVATE_USAGE_FEATURE_ENABLED="${SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED:-0}"
PRIVATE_USAGE_REQUIRES_CONFIGURATION=false
case "$PRIVATE_USAGE_FEATURE_ENABLED" in
    1|true|TRUE|True|yes|YES|Yes)
        PRIVATE_USAGE_REQUIRES_CONFIGURATION=true
        PRIVATE_USAGE_FEATURE_ENABLED=true
        ;;
    0|false|FALSE|False|no|NO|No|"")
        PRIVATE_USAGE_FEATURE_ENABLED=false
        ;;
    *)
        echo "SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED must be 1/0, true/false, or yes/no." >&2
        exit 2
        ;;
esac

PRIVATE_USAGE_ENVIRONMENT="${SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT:-}"
PRIVATE_USAGE_RELAY_URL="${SPILL_BUILD_PRIVATE_USAGE_RELAY_URL:-}"
PRIVATE_USAGE_WEB_URL="${SPILL_BUILD_PRIVATE_USAGE_WEB_URL:-}"
DEVELOPER_OPTIONS_ENABLED="${SPILL_DEVELOPER_OPTIONS_ENABLED:-}"

if [[ -n "$PRIVATE_USAGE_ENVIRONMENT" ]]; then
    case "$PRIVATE_USAGE_ENVIRONMENT" in
        development)
            ;;
        production)
            ;;
        *)
            echo "SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT must be development or production." >&2
            exit 2
            ;;
    esac
elif [[ "$PRIVATE_USAGE_REQUIRES_CONFIGURATION" == "true" ]]; then
    echo "SPILL_BUILD_PRIVATE_USAGE_ENVIRONMENT is required when SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED=1." >&2
    exit 2
fi

if [[ "${SPILL_DISABLE_SPARKLE:-0}" == "1" ]]; then
    SPARKLE_PUBLIC_ED_KEY=""
fi

validate_private_usage_url() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" && "$PRIVATE_USAGE_REQUIRES_CONFIGURATION" != "true" ]]; then
        return
    fi

    if [[ -z "$value" ]]; then
        echo "$name is required when SPILL_BUILD_PRIVATE_USAGE_FEATURE_ENABLED=1." >&2
        exit 2
    fi

    if [[ "$value" =~ ^https://[^[:space:]]+$ || "$value" =~ ^http://localhost(:[0-9]+)?([/?#].*)?$ ]]; then
        return
    fi

    echo "$name must be https or local http://localhost." >&2
    exit 2
}

sign_sparkle_framework() {
    local frameworks_dir="$1"
    local sparkle_version_dir="$frameworks_dir/Sparkle.framework/Versions/B"

    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/Autoupdate"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/Updater.app"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/XPCServices/Downloader.xpc"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$sparkle_version_dir/XPCServices/Installer.xpc"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$frameworks_dir/Sparkle.framework"
}

sign_app_bundle() {
    local app_dir="$1"
    local bundle_id="$2"

    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign \
            --force \
            --options runtime \
            --sign "$SIGN_IDENTITY" \
            --entitlements "$ENTITLEMENTS_PATH" \
            --requirements "=designated => identifier \"$bundle_id\"" \
            "$app_dir"
    else
        codesign \
            --force \
            --options runtime \
            --sign "$SIGN_IDENTITY" \
            --requirements "=designated => identifier \"$bundle_id\"" \
            "$app_dir"
    fi
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

validate_private_usage_url "SPILL_BUILD_PRIVATE_USAGE_RELAY_URL" "$PRIVATE_USAGE_RELAY_URL"
validate_private_usage_url "SPILL_BUILD_PRIVATE_USAGE_WEB_URL" "$PRIVATE_USAGE_WEB_URL"

if [[ -z "$DEVELOPER_OPTIONS_ENABLED" ]]; then
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        DEVELOPER_OPTIONS_ENABLED=true
    else
        DEVELOPER_OPTIONS_ENABLED=false
    fi
fi

case "$DEVELOPER_OPTIONS_ENABLED" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On)
        DEVELOPER_OPTIONS_ENABLED=true
        ;;
    0|false|FALSE|False|no|NO|No|off|OFF|Off)
        DEVELOPER_OPTIONS_ENABLED=false
        ;;
    *)
        echo "SPILL_DEVELOPER_OPTIONS_ENABLED must be 1/0, true/false, yes/no, or on/off." >&2
        exit 2
        ;;
esac

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

RESOURCE_BUNDLE="$(find "$ROOT_DIR/.build" -path "*/release/Spill_Spill.bundle" -type d -print -quit)"
if [[ -z "$RESOURCE_BUNDLE" ]]; then
    echo "Spill SwiftPM resource bundle was not found after swift build." >&2
    exit 2
fi
ditto "$RESOURCE_BUNDLE" "$RESOURCES_DIR/Spill_Spill.bundle"

ADAPTER_RESOURCES="$RESOURCES_DIR/Spill_Spill.bundle/adapters"
if [[ ! -d "$ADAPTER_RESOURCES" ]]; then
    echo "Spill adapter resources were not found in the SwiftPM resource bundle." >&2
    exit 2
fi
rm -rf "$RESOURCES_DIR/adapters"
ditto "$ADAPTER_RESOURCES" "$RESOURCES_DIR/adapters"

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
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>$BUNDLE_ID.private-usage</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>spill</string>
            </array>
        </dict>
    </array>
    <key>SPILLPrivateUsageEnvironment</key>
    <string>$PRIVATE_USAGE_ENVIRONMENT</string>
    <key>SPILLPrivateUsageRelayURL</key>
    <string>$PRIVATE_USAGE_RELAY_URL</string>
    <key>SPILLPrivateUsageWebURL</key>
    <string>$PRIVATE_USAGE_WEB_URL</string>
    <key>SPILLPrivateUsageFeatureEnabled</key>
    <$PRIVATE_USAGE_FEATURE_ENABLED/>
    <key>SPILLDeveloperOptionsEnabled</key>
    <$DEVELOPER_OPTIONS_ENABLED/>
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

mkdir -p "$HELPER_MACOS_DIR" "$HELPER_RESOURCES_DIR" "$HELPER_FRAMEWORKS_DIR"
cp "$MACOS_DIR/Spill" "$HELPER_MACOS_DIR/Spill"
ditto "$RESOURCES_DIR/Spill_Spill.bundle" "$HELPER_RESOURCES_DIR/Spill_Spill.bundle"
ditto "$RESOURCES_DIR/adapters" "$HELPER_RESOURCES_DIR/adapters"
ditto "$FRAMEWORKS_DIR/Sparkle.framework" "$HELPER_FRAMEWORKS_DIR/Sparkle.framework"
ditto "$RESOURCES_DIR/AppIcon.icns" "$HELPER_RESOURCES_DIR/AppIcon.icns"

cat > "$HELPER_CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Spill</string>
    <key>CFBundleIdentifier</key>
    <string>$HELPER_BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>Spill Token Dashboard</string>
    <key>CFBundleDisplayName</key>
    <string>Spill Token Dashboard</string>
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
    <key>SPILLDeveloperOptionsEnabled</key>
    <$DEVELOPER_OPTIONS_ENABLED/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Spill contributors</string>
$SPARKLE_INFO_PLIST_ENTRY
</dict>
</plist>
PLIST

sign_sparkle_framework "$FRAMEWORKS_DIR"
sign_sparkle_framework "$HELPER_FRAMEWORKS_DIR"
sign_app_bundle "$HELPER_APP_DIR" "$HELPER_BUNDLE_ID"
sign_app_bundle "$APP_DIR" "$BUNDLE_ID"

echo "Built $APP_DIR"
