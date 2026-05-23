# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A GitHub composite action that triggers a deployment on DeployHQ by invoking the official `dhq` CLI (<https://github.com/deployhq/deployhq-cli>). v1 (Docker + `curl` to a webhook URL) lives on the `v1` git tag and is no longer maintained on `main`.

## Architecture

`runs.using: composite` in `action.yml`. Two steps:

1. **Install dhq CLI** — `scripts/install-cli.sh` detects `RUNNER_OS`/`RUNNER_ARCH`, downloads the pinned `dhq` archive from `github.com/deployhq/deployhq-cli/releases`, verifies its SHA-256 against the release's `checksums.txt`, extracts to `$RUNNER_TOOL_CACHE/dhq/<version>/<os>_<arch>`, and appends that dir to `$GITHUB_PATH`. Cross-platform: Linux, macOS, Windows (Git Bash); amd64 + arm64.
2. **Deploy** — `scripts/deploy.sh` builds the `dhq deploy --json --non-interactive` argv from `INPUT_*` env vars, runs the CLI, parses the JSON envelope with `jq`, and emits action outputs + a `$GITHUB_STEP_SUMMARY` table.

### The `--wait` trick

`dhq deploy --json` returns immediately after queueing — its built-in `--wait` is a no-op in JSON mode (see `internal/commands/deploy.go` in the CLI). So `scripts/deploy.sh` implements waiting itself by polling `dhq deployments show <id> -p <project> --json` every 5s until the status is terminal (`completed`/`failed`/`cancelled`), respecting `INPUT_TIMEOUT`. If this changes upstream, the wait loop can be removed.

### Auth

Three required env vars passed straight through to the CLI: `DEPLOYHQ_API_KEY`, `DEPLOYHQ_ACCOUNT`, `DEPLOYHQ_EMAIL`. No `dhq auth login` call — the CLI reads these directly.

### Outputs

`scripts/deploy.sh` writes to `$GITHUB_OUTPUT`: `deployment_id`, `deployment_url`, `status`, `server`, `project`. The URL is constructed locally as `https://${DEPLOYHQ_ACCOUNT}.deployhq.com/projects/<permalink>/deployments/<id>` — the API doesn't return one. If the URL pattern changes server-side, fix it here.

### CLI version pin

The pinned default lives in **one place only**: `inputs.cli-version.default` in `action.yml`. Bump it there when validating against a new CLI release. Users can override per-workflow via the `cli-version` input.

## Things to know before editing

- **Two shells, one language.** Scripts use bash (`#!/usr/bin/env bash`, `set -euo pipefail`). On Windows runners GitHub's `shell: bash` picks Git Bash; `jq`, `tar`, `unzip`, `curl`, and `shasum`/`sha256sum` are all available there. Don't assume GNU-only flags.
- **`jq` is a hard dependency.** Preinstalled on all GitHub-hosted runners; self-hosted users must install it. The script fails fast with a clear message.
- **Exit codes are meaningful.** `0` success/queued, `1` deploy failed, `2` cancelled, `124` wait timeout, anything else = CLI error propagated.
- **`extra-args` is word-split unquoted by design** (escape hatch for new CLI flags). Don't quote it.
- **No `Dockerfile`/`entrypoint.sh`** — those live on `@v1`. Don't reintroduce them.
- Consumers can pin `@v2`, `@v2.x.y`, `@v1` (legacy), or `@main` (rolling).

## Local testing

```sh
DHQ_VERSION=v0.17.1 \
RUNNER_OS=$(uname -s) RUNNER_ARCH=$(uname -m) \
GITHUB_ACTION_PATH="$PWD" GITHUB_PATH=/tmp/gh-path \
./scripts/install-cli.sh

DEPLOYHQ_API_KEY=... DEPLOYHQ_ACCOUNT=... DEPLOYHQ_EMAIL=... \
INPUT_PROJECT=... INPUT_SERVER=... INPUT_REVISION=... \
INPUT_WAIT=false INPUT_DRY_RUN=true \
GITHUB_OUTPUT=/tmp/gh-output GITHUB_STEP_SUMMARY=/tmp/gh-summary \
./scripts/deploy.sh
```

(Set `GITHUB_OUTPUT`/`GITHUB_STEP_SUMMARY` to writable file paths when running outside Actions; they're appended-to, not created.)
