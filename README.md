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

> **Deploying to production?** The examples below use `@v2` for readability. `@v2` is a floating tag that moves with each v2 release — pin a commit SHA instead for any workflow holding production credentials. See [Pinning](#pinning).

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

## Pinning

This action receives production deploy credentials, so the ref you pin decides who can run code with them.

| Ref | Mutable? | Use when |
|---|---|---|
| `@<commit-sha>` | No — a commit SHA always names the same tree | **Recommended** for any workflow holding production secrets. |
| `@v2.0.0` | Yes — git tags can always be moved | You want a readable ref and accept that risk. |
| `@v2` | Yes, **by design** — tracks the latest v2.x.y | Non-production targets, or you accept implicit upgrades. |

`@v2` moves whenever a new v2 release ships. That is the point of a floating major tag, but it also means anyone with write access to this repository — or anyone who compromises that access — can change the code your deploy credentials run, with no review on your side. For production, pin the SHA and record the version alongside it:

```yaml
- uses: deployhq/deployhq-action@ffe9caa159b501c83cac4b70d2983078a316d15d # v2.0.0
  with:
    api-key: ${{ secrets.DEPLOYHQ_API_KEY }}
    account: ${{ secrets.DEPLOYHQ_ACCOUNT }}
    email:   ${{ secrets.DEPLOYHQ_EMAIL }}
    project: my-project
    server:  production
```

That SHA is `v2.0.0`. Don't copy it blindly once later releases exist — resolve the one you want:

```sh
gh api repos/deployhq/deployhq-action/commits/v2.0.0 --jq .sha
```

(Use the `commits` endpoint, not `git/ref/tags` — these are annotated tags, so `git/ref/tags` returns the tag object rather than the commit you need.)

### What SHA pinning does not cover

Pinning this action fixes the installer script and the default `cli-version`. It does **not** fix the bytes of the `dhq` binary: `scripts/install-cli.sh` downloads the CLI from `github.com/deployhq/deployhq-cli/releases` at run time and verifies it against a `checksums.txt` fetched from that same release. That catches a corrupted download, not someone able to replace the release assets.

If you need an immutable chain end-to-end, vendor the CLI yourself and call `dhq` directly rather than through this action. Installing `dhq` on the runner's `PATH` does **not** work — `scripts/install-cli.sh` downloads its own copy regardless and prepends that directory to `$GITHUB_PATH`. The one exception is a self-hosted runner, where you can pre-seed `$RUNNER_TOOL_CACHE/dhq/<version>/<os>_<arch>/dhq` (version without the leading `v`, e.g. `0.17.1/linux_amd64`); the installer reuses a binary already at that exact path instead of downloading.

### Bounding the blast radius

Pinning controls *what code* runs. These control *what it can reach*, and compose with it:

- Store `DEPLOYHQ_*` as **environment** secrets on a protected environment rather than repository secrets. Only a job that declares `environment: production` can request them, and they're released only once that environment's protection rules pass. The scoping alone doesn't stop another workflow from asking — the required reviewers and deployment branch policies you put on the environment are what actually gate it, so set them.
- Set `permissions: contents: read` on the job. This action needs no `GITHUB_TOKEN` scope.

### Keeping SHA pins current

Dependabot bumps SHA pins for you, rewriting both the SHA and the trailing version comment so upgrades arrive as reviewable pull requests. Merge this into your existing `.github/dependabot.yml` rather than replacing the file — clobbering it would silently disable your other ecosystems:

```yaml
version: 2
updates:
  # add alongside any existing entries
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

This only helps if a human reads the PR — exclude this action from any Dependabot auto-merge rule, or you get `@v2`'s implicit upgrades with a SHA pin's false confidence.

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
