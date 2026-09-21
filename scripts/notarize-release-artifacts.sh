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
# notarytool's own --timeout governs how long it waits for a submission to be
# judged. It does not cover a stalled transfer: a submit that never finishes
# uploading sits there with that timer unstarted. One release hung this step for
# nearly two hours and was still hanging when it was cancelled, burning a CI job
# and blocking the release, with --timeout 45m in effect the whole time. This is
# the backstop that does not depend on notarytool's internals, so it is
# deliberately longer than the value above rather than a second copy of it.
APPLE_NOTARYTOOL_HARD_TIMEOUT="${APPLE_NOTARYTOOL_HARD_TIMEOUT:-}"
NOTARYTOOL_LOG_DIR="${NOTARYTOOL_LOG_DIR:-$ROOT_DIR/.build/release-artifacts/notarytool-logs}"

# Accepts the forms notarytool itself takes -- 45m, 1h, 600s -- plus a bare
# number of seconds, so the backstop is expressed in the same units as the
# value it guards.
parse_duration_seconds() {
    local value="$1"
    local number="${value%[smh]}"
    if [[ ! "$number" =~ ^[0-9]+$ ]]; then
        echo "Invalid duration: $value" >&2
        return 1
    fi
    case "$value" in
        *h) echo $((number * 3600)) ;;
        *m) echo $((number * 60)) ;;
        *s) echo "$number" ;;
        *)  echo "$number" ;;
    esac
}

# Runs a command under a wall-clock deadline, because what is being guarded is
# a hang rather than a slow success. Terminates first and escalates only if that
# is ignored, so notarytool still gets the chance to print a submission id.
# Returns 124 on expiry, matching coreutils timeout, which a stock macOS runner
# does not have.
run_with_deadline() {
    local deadline="$1"
    shift
    "$@" &
    local pid=$!
    local waited=0
    # Polled in short steps so a submission that finishes normally is not held
    # back by the granularity of the guard watching it.
    local step=2
    while kill -0 "$pid" 2>/dev/null; do
        if (( waited >= deadline )); then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 10
            kill -KILL "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            return 124
        fi
        sleep "$step"
        waited=$((waited + step))
    done
    wait "$pid"
}
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

# Resolved once: the backstop defaults to notarytool's own timeout plus ten
# minutes, so raising APPLE_NOTARYTOOL_TIMEOUT moves the guard with it instead
# of silently capping it.
notarytool_hard_deadline="$(
    if [[ -n "$APPLE_NOTARYTOOL_HARD_TIMEOUT" ]]; then
        parse_duration_seconds "$APPLE_NOTARYTOOL_HARD_TIMEOUT"
    else
        echo $(( $(parse_duration_seconds "$APPLE_NOTARYTOOL_TIMEOUT") + 600 ))
    fi
)"

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
    local submit_status=0
    run_with_deadline "$notarytool_hard_deadline" \
        xcrun notarytool submit \
        "${notarytool_auth_args[@]}" \
        --wait \
        --timeout "$APPLE_NOTARYTOOL_TIMEOUT" \
        --output-format json \
        "$submission_path" > "$submit_json" || submit_status=$?

    if (( submit_status == 124 )); then
        echo "notarytool submit exceeded the hard deadline of ${notarytool_hard_deadline}s for $artifact and was terminated." >&2
        echo "notarytool's own --timeout of $APPLE_NOTARYTOOL_TIMEOUT did not fire, which is what this backstop exists for: a stalled upload never starts that timer." >&2
        if submission_id="$(json_field "$submit_json" id 2>/dev/null)"; then
            echo "Partial submission output names id: $submission_id" >&2
            fetch_notarytool_log "$submission_id" "$rejection_log"
        fi
        echo "Saved submission output: $submit_json" >&2
        echo "Re-running the release workflow is the normal remedy; the stall is on Apple's side and the tag needs no change." >&2
        exit 1
    fi

    if (( submit_status != 0 )); then
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
for ((index = 0; index < ${#artifact_dirs[@]}; index++)); do
    dir="${artifact_dirs[$index]}"
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
