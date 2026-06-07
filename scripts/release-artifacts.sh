#!/usr/bin/env bash

canonical_artifact_path() {
    local artifact_path="${1:?artifact path is required}"
    local artifact_dir
    artifact_dir="$(cd "$(dirname "$artifact_path")" && pwd -P)"
    printf '%s/%s\n' "$artifact_dir" "$(basename "$artifact_path")"
}

safe_artifact_label() {
    local artifact_path="${1:?artifact path is required}"
    local basename_label
    local path_hash
    basename_label="$(basename "$artifact_path")"
    basename_label="$(printf '%s' "$basename_label" | tr -c 'A-Za-z0-9._-' '_')"
    path_hash="$(canonical_artifact_path "$artifact_path" | shasum -a 256 | awk '{print substr($1, 1, 12)}')"
    printf '%s.%s\n' "$basename_label" "$path_hash"
}

collect_unique_artifacts() {
    local artifacts=()
    local artifact
    local canonical
    local existing
    local duplicate

    for artifact in "$@"; do
        [[ -e "$artifact" ]] || continue
        canonical="$(canonical_artifact_path "$artifact")"
        duplicate=false
        for existing in "${artifacts[@]}"; do
            if [[ "$(canonical_artifact_path "$existing")" == "$canonical" ]]; then
                duplicate=true
                break
            fi
        done
        if [[ "$duplicate" == false ]]; then
            artifacts+=("$artifact")
        fi
    done

    if [[ ${#artifacts[@]} -gt 0 ]]; then
        printf '%s\0' "${artifacts[@]}"
    fi
}
