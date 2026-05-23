# Changelog

## v2.0.0 — Switch to the official DeployHQ CLI

This is a breaking rewrite. The action now wraps the [`dhq` CLI](https://github.com/deployhq/deployhq-cli) instead of POSTing to a webhook URL. To stay on the old behaviour, pin `@v1`.

### Breaking changes

- **Auth**: webhook URL replaced by API key. New required inputs: `api-key`, `account`, `email`.
- **Input style**: inputs are now declared properly (`with:`) instead of passed via `env:`. The legacy `DEPLOYHQ_*` env vars are no longer recognised.
- **Removed inputs**: `DEPLOYHQ_WEBHOOK_URL`, `REPO_CLONE_URL`. The CLI resolves the repository from the project configuration.
- **Defaults changed**: `revision` defaults to `${{ github.sha }}` (was `"latest"`). `branch` no longer defaults to `main` — the CLI auto-resolves it from server config.
- **Runtime**: Docker (Alpine) action replaced by a composite action. Runs on Linux, macOS, and Windows runners, including self-hosted.

### Added

- New inputs: `project`, `server`, `wait`, `timeout`, `dry-run`, `full`, `start-revision`, `extra-args`, `cli-version`.
- New outputs: `deployment_id`, `deployment_url`, `status`, `server`, `project`.
- Built-in wait-for-completion with timeout (polls `dhq deployments show` until terminal).
- Job step summary table with deployment ID, status, project, server, and link.
- Pinned CLI version with SHA-256 checksum verification on download.

### Migration

See the **Migration from v1** section in `README.md`.

## v1.x — Legacy Docker webhook action

Final webhook-based release. Maintained on the `v1` tag only.
