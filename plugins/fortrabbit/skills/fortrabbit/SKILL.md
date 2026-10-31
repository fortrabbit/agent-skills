---
name: fortrabbit
description: >-
  Deploys, operates and troubleshoots PHP apps hosted on fortrabbit (Laravel, Craft CMS, Statamic,
  Kirby, WordPress, Symfony, plain PHP). Covers finding the environment of the current repo,
  git push and CLI deployments, deployment logs, environment variables, remote commands over SSH
  (artisan, craft, wp-cli, composer), database pull and push, file and content sync with rsync,
  HTTP 500/503/504 diagnosis, creating apps and environments over the fortrabbit MCP server, and
  connecting an agent to fortrabbit through MCP or the frbit CLI. Use it whenever the user
  mentions fortrabbit, frbit, a frbit.app or frbit.cloud hostname, an en-xxxxxx or ap-xxxxxx ID,
  works in a repo with a .fortrabbit/deploy.yml,
  pastes a fortrabbit deployment log or an SSH error from ssh.<region>.frbit.app, or asks to
  deploy, sync or debug a PHP site that is hosted there, even without naming fortrabbit.
license: MIT
compatibility: >-
  Needs git and ssh (port 22). rsync for file sync, a MySQL client for database work. Works best
  with the fortrabbit MCP server (https://mcp.fortrabbit.com/mcp) and the frbit CLI connected.
  On Windows, rsync needs WSL.
metadata:
  version: "2.7.0"
  author: fortrabbit
---

# fortrabbit

fortrabbit hosts PHP apps. An **app** has one or more **environments** (`en-xxxxxx`), for example production and staging. Each environment has components (PHP, MySQL, storage, jobs), a default domain `https://<env>.<region>.frbit.app` that forwards to its main domain (usually a cloud domain `https://<label>.frbit.cloud` or a custom domain), SSH access, and usually a GitHub repository and branch it deploys from.

## Safety first

- Production is live. Show the exact command or tool call before anything that changes state, and wait for a yes before: deploying, restarting, changing environment variables, database push or pull, rsync to or from the environment, creating billed resources.
- Deleting an app, environment, domain or team: say what will be lost (domains, files, database, people, billing), then wait for a clear yes in the user's next message. The request that started the task is not that yes. `--confirm <id>` on the CLI is a typo guard, not consent. Offer the dashboard confirm screen too: `https://dash.fortrabbit.com/delete/environment?environment=<id>`.
- Never ask for a password or token in the chat, and never write one to a file in the repo. Sign-in happens in the browser (MCP OAuth, `frbit auth login`), by the person: show them the sign-in URL, and never open it, fill in or approve the sign-in or consent page with a browser or computer-use tool. The database password stays in the dashboard and is typed into a password prompt by the person.
- Never guess an ID, region, plan size or software version. Look it up (see below).

## Which tool for what

Use the first route the agent has. A missing MCP tool is not a missing capability: check the CLI before saying something cannot be done.

| Need | MCP (`fortrabbit` server) | frbit CLI | Other |
|---|---|---|---|
| Account, apps, environments, deployments, domains | `get_you`, `list_*`, `get_*` | `frbit <group> list/get --json` | |
| Create an app or environment | `create_app`, `create_environment` | `frbit apps create`, `frbit environments create` | |
| Environment variables | `get_environment`, `update_environment` | `frbit environments variables get/update` | |
| Branch, build and post-deploy commands | `update_environment` | `frbit environments update` | |
| PHP version | – | `frbit environments create --php-version`, `frbit environments update --file` | dashboard |
| Deploy | push to the connected branch | `frbit environments deploy <env>` | deploy hook URL |
| Restart | – | `frbit environments restart <env>` | |
| Why a deployment failed | `get_deployment`, `get_deployment_logs` | `frbit deployments logs <dp>` | |
| Delete | – | `frbit <group> delete`, after a yes | dashboard |
| Remote commands, database, files | – | – | `ssh`, `mysql`, `rsync` |
| Runtime logs (PHP, Apache, jobs) | – | – | dashboard Logs tab, or log files over SSH |

No MCP server and no CLI yet? Connecting takes one command: [references/access.md](references/access.md).

No shell, as in claude.ai chat or Cowork: only the MCP column works. Say which steps need a terminal (SSH, database, files, deploy, restart), give the person the exact command with IDs filled in to run themselves, and offer the dashboard route where there is one.

## Find the environment

Do not ask for an ID before trying this. Resolve it once per session and reuse it.

1. `git remote get-url origin` → `owner/repo`, and `git branch --show-current`.
2. MCP: `list_git_repositories` → the entry with that `fullName` has `connectedAppPublicId`. `get_app` on it → `region` (e.g. `eu-w1a`) and its `environments`. `list_environments` → of those, the one whose `git.branch` is the current branch. If several match or none does, list the environments by name and ask which one.
3. Without MCP: `frbit apps list --json`, `frbit apps get <app> --json` and `frbit environments list --json`, matched the same way.
4. Derived from that, nothing to store:
   - SSH: `<env>@ssh.<region>.frbit.app`
   - Default domain: `https://<env>.<region>.frbit.app`. The live URL is the main domain: `list_domains`, `isMain`
   - Database name and user: the environment ID

No MCP tools, or a `401`: connect first ([references/access.md](references/access.md)). No account yet, or no match: the repo is not on fortrabbit yet, see [references/boarding.md](references/boarding.md). A deploy file `.fortrabbit/deploy.yml` (or `.yaml`, `.json`) means the repo deploys to fortrabbit and holds its deployment settings: read it before changing any ([deploy.md](references/deploy.md#deploy-file)). A plain `.fortrabbit` file is a 1.x leftover, ignore it.

## References

Load the one file that fits the request, two at most.

| Request | File |
|---|---|
| New to fortrabbit, no account, no app, "host this project" | [boarding.md](references/boarding.md) |
| Connect MCP, CLI or the REST API, `401`, tokens | [access.md](references/access.md) |
| MCP tool details: arguments, creating apps and environments | [mcp.md](references/mcp.md) |
| Deploy, deployment status, failed deployment, deploy hook, build and post-deploy commands | [deploy.md](references/deploy.md) |
| Connect a GitHub repo, the fortrabbit GitHub App | [git-github.md](references/git-github.md) |
| Run artisan, craft, wp-cli, composer remotely, SSH keys, SSH errors | [ssh.md](references/ssh.md) |
| Database pull, push, dump, import, connect a client | [database.md](references/database.md) |
| Sync uploads, assets, content or all files with rsync | [files.md](references/files.md) |
| Site returns 404, 500, 503, 504, is slow, "is it live?" | [troubleshooting.md](references/troubleshooting.md) |
| Laravel, Craft CMS, Statamic, Kirby, WordPress specifics, local dev (DDEV) | [software.md](references/software.md) |

Docs: `https://docs.fortrabbit.com/llms.txt` lists every page. Fetch a page as Markdown by inserting `/raw` and appending `.md`: `https://docs.fortrabbit.com/raw/platform/deployment/intro.md`.
