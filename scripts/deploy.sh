#!/usr/bin/env bash
#
# Invoke `dhq deploy` with arguments derived from INPUT_* env vars, parse the
# JSON envelope, and emit action outputs + a step summary.
#
# In JSON mode the CLI returns immediately after queueing (see
# internal/commands/deploy.go ~L434), so this script handles --wait itself by
# polling `dhq deployments show` until the deployment reaches a terminal status.
set -euo pipefail

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required but was not found on PATH." >&2
        echo "GitHub-hosted runners ship with jq; install it on self-hosted runners." >&2
        exit 1
    fi
}

truthy() {
    case "${1:-}" in
        true|TRUE|True|1|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

emit_output() {
    local name="$1" value="$2"
    if [[ "$value" == *$'\n'* ]]; then
        local delim="ghadelim_$RANDOM"
        printf '%s<<%s\n%s\n%s\n' "$name" "$delim" "$value" "$delim" >> "$GITHUB_OUTPUT"
    else
        printf '%s=%s\n' "$name" "$value" >> "$GITHUB_OUTPUT"
    fi
}

require_jq

# --- Build dhq deploy argv -----------------------------------------------------

args=(deploy --json --non-interactive)

[[ -n "${INPUT_PROJECT:-}"        ]] && args+=(--project        "$INPUT_PROJECT")
[[ -n "${INPUT_SERVER:-}"         ]] && args+=(--server         "$INPUT_SERVER")
[[ -n "${INPUT_REVISION:-}"       ]] && args+=(--revision       "$INPUT_REVISION")
[[ -n "${INPUT_BRANCH:-}"         ]] && args+=(--branch         "$INPUT_BRANCH")
[[ -n "${INPUT_START_REVISION:-}" ]] && args+=(--start-revision "$INPUT_START_REVISION")
[[ -n "${INPUT_TIMEOUT:-}"        ]] && args+=(--timeout        "$INPUT_TIMEOUT")
truthy "${INPUT_FULL:-}"    && args+=(--full)
truthy "${INPUT_DRY_RUN:-}" && args+=(--dry-run)

# --wait is handled by this script, not the CLI (see header).

if [[ -n "${INPUT_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    extra=( $INPUT_EXTRA_ARGS )
    args+=("${extra[@]}")
fi

echo "::group::dhq ${args[*]}"
set +e
deploy_output=$(dhq "${args[@]}")
deploy_exit=$?
set -e
printf '%s\n' "$deploy_output"
echo "::endgroup::"

if [[ $deploy_exit -ne 0 ]]; then
    echo "dhq deploy exited $deploy_exit" >&2
    # Still try to surface envelope error data if we got any.
    if [[ -n "$deploy_output" ]] && echo "$deploy_output" | jq -e . >/dev/null 2>&1; then
        echo "$deploy_output" | jq -r '.data.error // empty' >&2 || true
    fi
    exit "$deploy_exit"
fi

# --- Parse envelope -----------------------------------------------------------

if ! echo "$deploy_output" | jq -e '.ok == true' >/dev/null 2>&1; then
    echo "dhq deploy returned a non-ok envelope:" >&2
    echo "$deploy_output" >&2
    exit 1
fi

deployment_id=$(echo "$deploy_output" | jq -r '.data.identifier // empty')
status=$(echo "$deploy_output"        | jq -r '.data.status // empty')
project_permalink=$(echo "$deploy_output" | jq -r '.data.project.permalink // empty')
server_id=$(echo "$deploy_output"     | jq -r '.data.servers[0].identifier // empty')

if [[ -z "$deployment_id" ]]; then
    echo "Could not extract deployment identifier from response." >&2
    exit 1
fi

# Project identifier used for follow-up calls — prefer the value the user passed
# in (it's what the CLI was configured with), fall back to the permalink.
project_for_polling="${INPUT_PROJECT:-$project_permalink}"

deployment_url=""
if [[ -n "${DEPLOYHQ_ACCOUNT:-}" && -n "$project_permalink" ]]; then
    deployment_url="https://${DEPLOYHQ_ACCOUNT}.deployhq.com/projects/${project_permalink}/deployments/${deployment_id}"
fi

# --- Wait loop ----------------------------------------------------------------

if truthy "${INPUT_WAIT:-}" && ! truthy "${INPUT_DRY_RUN:-}"; then
    timeout_seconds="${INPUT_TIMEOUT:-0}"
    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
        echo "INPUT_TIMEOUT must be a non-negative integer number of seconds (got: ${timeout_seconds})." >&2
        exit 1
    fi
    started=$(date +%s)
    poll_interval=5
    consecutive_errors=0
    max_consecutive_errors=12  # ~1 minute of repeated failures at 5s intervals

    echo "Waiting for deployment ${deployment_id} to complete..."
    while true; do
        if [[ "$timeout_seconds" -gt 0 ]]; then
            elapsed=$(( $(date +%s) - started ))
            if [[ $elapsed -ge $timeout_seconds ]]; then
                echo "Timed out after ${timeout_seconds}s waiting for deployment ${deployment_id}" >&2
                status="timeout"
                break
            fi
        fi

        sleep "$poll_interval"

        show_output=$(dhq deployments show "$deployment_id" -p "$project_for_polling" --json --non-interactive 2>/dev/null || true)
        if [[ -z "$show_output" ]] || ! echo "$show_output" | jq -e '.ok == true' >/dev/null 2>&1; then
            consecutive_errors=$(( consecutive_errors + 1 ))
            if [[ $consecutive_errors -ge $max_consecutive_errors ]]; then
                echo "Failed to fetch deployment status ${consecutive_errors} times in a row; giving up." >&2
                status="failed"
                break
            fi
            echo "Failed to fetch deployment status (${consecutive_errors}/${max_consecutive_errors}); will retry..."
            continue
        fi
        consecutive_errors=0

        status=$(echo "$show_output" | jq -r '.data.status // empty')
        echo "  status: ${status}"

        case "$status" in
            completed|failed|cancelled) break ;;
        esac
    done
fi

# --- Outputs ------------------------------------------------------------------

emit_output "deployment_id"  "$deployment_id"
emit_output "deployment_url" "$deployment_url"
emit_output "status"         "$status"
emit_output "server"         "$server_id"
emit_output "project"        "$project_permalink"

# --- Step summary -------------------------------------------------------------

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "### DeployHQ deployment"
        echo ""
        echo "| Field | Value |"
        echo "| --- | --- |"
        echo "| ID | \`${deployment_id}\` |"
        [[ -n "$status"            ]] && echo "| Status | \`${status}\` |"
        [[ -n "$project_permalink" ]] && echo "| Project | \`${project_permalink}\` |"
        [[ -n "$server_id"         ]] && echo "| Server | \`${server_id}\` |"
        [[ -n "$deployment_url"    ]] && echo "| URL | <${deployment_url}> |"
    } >> "$GITHUB_STEP_SUMMARY"
fi

# --- Exit code ----------------------------------------------------------------

case "$status" in
    failed)    exit 1 ;;
    timeout)   exit 124 ;;
    cancelled) exit 2 ;;
    *)         exit 0 ;;
esac
