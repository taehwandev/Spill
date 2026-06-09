#!/usr/bin/env bash
set -euo pipefail

NOTARYTOOL_API_KEY_VALUE="${APPLE_NOTARYTOOL_API_KEY:-}"
unset APPLE_NOTARYTOOL_API_KEY

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "macOS notarization must run on macOS." >&2
    exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-artifacts.sh"

APPLE_NOTARYTOOL_TIMEOUT="${APPLE_NOTARYTOOL_TIMEOUT:-45m}"
NOTARYTOOL_LOG_DIR="${NOTARYTOOL_LOG_DIR:-$ROOT_DIR/.build/release-artifacts/notarytool-logs}"
TEMP_KEY_DIR=""
TEMP_SUBMISSION_DIR=""

cleanup() {
    if [[ -n "$TEMP_KEY_DIR" ]]; then
        rm -rf "$TEMP_KEY_DIR"
    fi
    if [[ -n "$TEMP_SUBMISSION_DIR" ]]; then
        rm -rf "$TEMP_SUBMISSION_DIR"
    fi
}
trap cleanup EXIT

usage() {
    cat <<'USAGE'
Usage:
  scripts/notarize-release-artifacts.sh --app .build/Spill.app
  scripts/notarize-release-artifacts.sh --artifacts .build/release-artifacts
  scripts/notarize-release-artifacts.sh <artifact> [...]

Uses App Store Connect API key notarization only.
USAGE
}

notarytool_auth_args=()

build_notarytool_auth_args() {
    if [[ -n "${APPLE_NOTARYTOOL_PROFILE:-}" || -n "${APPLE_NOTARYTOOL_KEYCHAIN:-}" ]]; then
        if [[ -n "$NOTARYTOOL_API_KEY_VALUE" || -n "${APPLE_NOTARYTOOL_API_KEY_PATH:-}" ]]; then
            echo "Set only one notarytool auth method: API key env/path or keychain profile auth." >&2
        else
            echo "notarytool keychain profile auth is not supported by the Spill release pipeline. Use App Store Connect API key auth." >&2
        fi
        exit 2
    fi

    if [[ -n "$NOTARYTOOL_API_KEY_VALUE" && -n "${APPLE_NOTARYTOOL_API_KEY_PATH:-}" ]]; then
        echo "Set only one of APPLE_NOTARYTOOL_API_KEY or APPLE_NOTARYTOOL_API_KEY_PATH." >&2
        exit 2
    fi

    if [[ -z "$NOTARYTOOL_API_KEY_VALUE" && -z "${APPLE_NOTARYTOOL_API_KEY_PATH:-}" ]]; then
        echo "APPLE_NOTARYTOOL_API_KEY is required for App Store Connect API-key notarization." >&2
        exit 2
    fi

    if [[ -z "${APPLE_NOTARYTOOL_API_KEY_ID:-}" || -z "${APPLE_NOTARYTOOL_API_ISSUER:-}" ]]; then
        echo "APPLE_NOTARYTOOL_API_KEY_ID and APPLE_NOTARYTOOL_API_ISSUER are required for App Store Connect API-key notarization." >&2
        exit 2
    fi

    local api_key_path="${APPLE_NOTARYTOOL_API_KEY_PATH:-}"
    if [[ -n "$NOTARYTOOL_API_KEY_VALUE" ]]; then
        TEMP_KEY_DIR="$(mktemp -d)"
        api_key_path="$TEMP_KEY_DIR/notarytool-api-key.p8"
        (umask 077 && printf '%s' "$NOTARYTOOL_API_KEY_VALUE" > "$api_key_path")
        unset NOTARYTOOL_API_KEY_VALUE
    fi

    notarytool_auth_args=(
        --key "$api_key_path"
        --key-id "$APPLE_NOTARYTOOL_API_KEY_ID"
        --issuer "$APPLE_NOTARYTOOL_API_ISSUER"
    )
}

json_field() {
    local json_file="${1:?json file is required}"
    local field_name="${2:?field name is required}"
    node -e '
        const fs = require("node:fs");
        const [file, field] = process.argv.slice(1);
        let parsed;
        try {
          parsed = JSON.parse(fs.readFileSync(file, "utf8"));
        } catch (error) {
          console.error(`Failed to parse notarytool JSON output: ${error.message}`);
          process.exit(2);
        }
        const value = parsed[field];
        if (value === undefined || value === null || value === "") {
          console.error(`Missing ${field} in notarytool JSON output.`);
          process.exit(2);
        }
        process.stdout.write(String(value));
    ' "$json_file" "$field_name"
}

submission_path_for() {
    local artifact="${1:?artifact is required}"
    if [[ -d "$artifact" && "$artifact" == *.app ]]; then
        mkdir -p "$TEMP_SUBMISSION_DIR"
        local zip_path="$TEMP_SUBMISSION_DIR/$(basename "$artifact").notary.zip"
        ditto -c -k --sequesterRsrc --keepParent "$artifact" "$zip_path"
        printf '%s\n' "$zip_path"
    else
        printf '%s\n' "$artifact"
    fi
}

fetch_notarytool_log() {
    local submission_id="${1:?submission id is required}"
    local log_path="${2:?log path is required}"
    if xcrun notarytool log "${notarytool_auth_args[@]}" "$submission_id" > "$log_path" 2>&1; then
        echo "Saved notarization log: $log_path" >&2
    else
        echo "Could not fetch notarization log for submission id $submission_id." >&2
    fi
}

notarize_artifact() {
    local artifact="${1:?artifact is required}"
    local artifact_label
    local submit_json
    local rejection_log
    local submission_path
    local submission_id
    local status

    artifact_label="$(safe_artifact_label "$artifact")"
    submit_json="$NOTARYTOOL_LOG_DIR/$artifact_label.notarytool-submit.json"
    rejection_log="$NOTARYTOOL_LOG_DIR/$artifact_label.notarytool-log.json"
    submission_path="$(submission_path_for "$artifact")"

    echo "Submitting artifact for notarization: $artifact"
    if ! xcrun notarytool submit \
        "${notarytool_auth_args[@]}" \
        --wait \
        --timeout "$APPLE_NOTARYTOOL_TIMEOUT" \
        --output-format json \
        "$submission_path" > "$submit_json"; then
        submission_id=""
        if submission_id="$(json_field "$submit_json" id 2>/dev/null)"; then
            echo "notarytool submit failed for $artifact (submission id: $submission_id)." >&2
            echo "Saved submission output: $submit_json" >&2
            fetch_notarytool_log "$submission_id" "$rejection_log"
        else
            echo "notarytool submit failed for $artifact before a submission id was returned." >&2
            echo "Saved submission output: $submit_json" >&2
        fi
        exit 1
    fi

    if ! submission_id="$(json_field "$submit_json" id)" || ! status="$(json_field "$submit_json" status)"; then
        echo "notarytool returned unreadable JSON output: $submit_json" >&2
        exit 1
    fi

    echo "Notarization finished for artifact: $artifact (submission id: $submission_id, status: $status)"
    if [[ "$status" != "Accepted" ]]; then
        echo "notarytool did not accept $artifact (submission id: $submission_id, status: $status)." >&2
        echo "Saved submission output: $submit_json" >&2
        fetch_notarytool_log "$submission_id" "$rejection_log"
        exit 1
    fi

    echo "Stapling notarization ticket to artifact: $artifact"
    xcrun stapler staple "$artifact"
    xcrun stapler validate "$artifact"
}

declare -a artifact_args=()
declare -a artifact_dirs=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            shift
            [[ $# -gt 0 ]] || { usage >&2; exit 2; }
            artifact_args+=("$1")
            ;;
        --artifacts)
            shift
            [[ $# -gt 0 ]] || { usage >&2; exit 2; }
            artifact_dirs+=("$1")
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                artifact_args+=("$1")
                shift
            done
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            artifact_args+=("$1")
            ;;
    esac
    shift
done

shopt -s nullglob
for dir in "${artifact_dirs[@]}"; do
    artifact_args+=("$dir"/Spill-*-macos.dmg)
done

if [[ ${#artifact_args[@]} -eq 0 ]]; then
    echo "No release artifacts were provided for notarization." >&2
    usage >&2
    exit 2
fi

mkdir -p "$NOTARYTOOL_LOG_DIR"
TEMP_SUBMISSION_DIR="$(mktemp -d)"
build_notarytool_auth_args

declare -a artifacts=()
while IFS= read -r -d '' artifact; do
    artifacts+=("$artifact")
done < <(collect_unique_artifacts "${artifact_args[@]}")

if [[ ${#artifacts[@]} -eq 0 ]]; then
    echo "No existing release artifacts were found for notarization." >&2
    exit 2
fi

for artifact in "${artifacts[@]}"; do
    if xcrun stapler validate "$artifact" >/dev/null 2>&1; then
        echo "Artifact already has a stapled notarization ticket: $artifact"
        continue
    fi
    notarize_artifact "$artifact"
done

echo "Release artifacts are notarized and stapled."
