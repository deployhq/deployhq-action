# DeployHQ — GitHub Action

Trigger a deployment on [DeployHQ](https://www.deployhq.com/) from a GitHub workflow. Wraps the official [`dhq` CLI](https://github.com/deployhq/deployhq-cli) so customers, agents, and CI all share one tool.

> **Looking for the legacy webhook action?** That's v1. Pin `deployhq/deployhq-action@v1` to keep the old behaviour. See [Migration from v1](#migration-from-v1) below.

## Quick start

```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger DeployHQ deployment
        uses: deployhq/deployhq-action@v2
        with:
          api-key: ${{ secrets.DEPLOYHQ_API_KEY }}
          account: ${{ secrets.DEPLOYHQ_ACCOUNT }}
          email:   ${{ secrets.DEPLOYHQ_EMAIL }}
          project: my-project
          server:  production
```

The action installs the pinned `dhq` CLI on the runner, calls `dhq deploy`, waits for the deployment to reach a terminal status, and fails the job if it didn't succeed.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `api-key` | **yes** | — | DeployHQ API key. Generate one in **Account Settings → API access**. |
| `account` | **yes** | — | Your DeployHQ account subdomain (e.g. `acme` for `acme.deployhq.com`). |
| `email` | **yes** | — | DeployHQ user email associated with the API key. |
| `project` | no | `""` | Project identifier or permalink. Falls back to `DEPLOYHQ_PROJECT` if unset. |
| `server` | no | `""` | Server identifier or name. Fuzzy-matched. Auto-selected if the project has only one server. |
| `revision` | no | `${{ github.sha }}` | Commit SHA to deploy. |
| `branch` | no | `""` | Branch the revision lives on. Auto-resolved from server config if omitted. |
| `wait` | no | `"true"` | Block until the deployment reaches a terminal status. Job exit code reflects the result. |
| `timeout` | no | `"0"` | Max seconds to wait when `wait=true`. `0` waits indefinitely. |
| `dry-run` | no | `"false"` | Preview the deploy without executing it. |
| `full` | no | `"false"` | Deploy the entire branch from the first commit (`--full`). |
| `start-revision` | no | `""` | Start an incremental deploy from this commit. |
| `extra-args` | no | `""` | Additional raw flags appended to `dhq deploy`. Escape hatch for newer CLI flags. |
| `cli-version` | no | pinned | Pin a specific `dhq` CLI release (e.g. `v0.17.1`). Defaults to the version this action was tested against. |

## Outputs

| Name | Description |
|---|---|
| `deployment_id` | DeployHQ deployment identifier (e.g. `dep-abc123`). |
| `deployment_url` | Web URL of the deployment in DeployHQ. |
| `status` | Final status (`completed`/`failed`/`cancelled`/`timeout`) when `wait=true`, else the queued status. |
| `server` | Resolved server identifier. |
| `project` | Resolved project permalink. |

```yaml
- id: deploy
  uses: deployhq/deployhq-action@v2
  with:
    api-key: ${{ secrets.DEPLOYHQ_API_KEY }}
    account: ${{ secrets.DEPLOYHQ_ACCOUNT }}
    email:   ${{ secrets.DEPLOYHQ_EMAIL }}
    project: my-project
    server:  production

- name: Open deployment
  if: success()
  run: echo "Deployed → ${{ steps.deploy.outputs.deployment_url }}"
```

## Common patterns

### Don't block the workflow on the deploy

```yaml
- uses: deployhq/deployhq-action@v2
  with:
    api-key: ${{ secrets.DEPLOYHQ_API_KEY }}
    account: ${{ secrets.DEPLOYHQ_ACCOUNT }}
    email:   ${{ secrets.DEPLOYHQ_EMAIL }}
    project: my-project
    server:  production
    wait:    "false"
```

### Dry-run on pull requests

```yaml
- uses: deployhq/deployhq-action@v2
  with:
    api-key:  ${{ secrets.DEPLOYHQ_API_KEY }}
    account:  ${{ secrets.DEPLOYHQ_ACCOUNT }}
    email:    ${{ secrets.DEPLOYHQ_EMAIL }}
    project:  my-project
    server:   staging
    dry-run:  "true"
```

### Pass through a flag the action doesn't expose yet

```yaml
- uses: deployhq/deployhq-action@v2
  with:
    api-key:    ${{ secrets.DEPLOYHQ_API_KEY }}
    account:    ${{ secrets.DEPLOYHQ_ACCOUNT }}
    email:      ${{ secrets.DEPLOYHQ_EMAIL }}
    project:    my-project
    server:     production
    extra-args: "--copy-config --run-build"
```

## Requirements

- A DeployHQ API key (**Account Settings → API access**).
- Runner with `bash`, `curl`, and `jq` available. GitHub-hosted runners (Ubuntu, macOS, Windows) ship with all three. Self-hosted runners must install `jq`.

## Migration from v1

v1 was a Docker action that POSTed to a webhook URL. v2 is a composite action that calls the `dhq` CLI directly.

| v1 input (env var) | v2 input | Notes |
|---|---|---|
| `DEPLOYHQ_WEBHOOK_URL` | _(removed)_ | Replaced by API key auth. |
| `DEPLOYHQ_EMAIL` | `email` | Now declared as a proper action input. |
| `REPO_REVISION` | `revision` | Defaults to `github.sha` instead of `"latest"`. |
| `REPO_BRANCH` | `branch` | Default `main` removed — CLI auto-resolves from server config. |
| `REPO_CLONE_URL` | _(removed)_ | CLI looks up the repo from the project config. |
| _(n/a)_ | `api-key`, `account` | **New required inputs.** |
| _(n/a)_ | `server`, `project` | Target a specific server/project. |
| _(n/a)_ | `wait`, `timeout`, `dry-run`, `full`, `start-revision`, `extra-args`, `cli-version` | New behaviour controls. |

**To stay on v1**, pin to it:

```yaml
uses: deployhq/deployhq-action@v1
```

**To migrate to v2:**

1. Generate an API key in DeployHQ (**Account Settings → API access**).
2. Add `DEPLOYHQ_API_KEY` and `DEPLOYHQ_ACCOUNT` as repository secrets. (`DEPLOYHQ_EMAIL` you already have.)
3. Switch your workflow to `with:` syntax (see [Quick start](#quick-start)).
4. Set `project:` and `server:` explicitly — the webhook implied these; the API requires them.
5. Remove `DEPLOYHQ_WEBHOOK_URL` from your secrets when no other workflow uses it.

## License

MIT. See [LICENSE](LICENSE).
