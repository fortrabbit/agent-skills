---
name: fortrabbit
description: >-
  Handles any request about fortrabbit, the PHP hosting platform: the user's account, apps,
  environments, deployments, domains and environment variables, and deploying, operating and
  troubleshooting Laravel, Craft CMS, Statamic, Kirby, WordPress, Symfony or plain PHP apps hosted
  there. Covers finding the environment of the current repo, git push and CLI deployments,
  deployment logs, remote commands over SSH (artisan, craft, wp-cli, composer), database pull and
  push, file sync with rsync, HTTP 500/503/504 diagnosis, moving a site from another host,
  creating apps and environments over the fortrabbit MCP server, and connecting an agent through MCP or the frbit
  CLI. Use it whenever the user mentions fortrabbit or frbit, a frbit.app or frbit.cloud hostname,
  an en-xxxxxx or ap-xxxxxx ID, works in a repo with a .fortrabbit/deploy.yml, pastes a fortrabbit
  deployment log or an SSH error from ssh.[region].frbit.app, or asks to deploy, sync or debug a
  PHP site hosted there, even without naming fortrabbit.
license: MIT
compatibility: >-
  Needs git and ssh (port 22). rsync for file sync, a MySQL client for database work. Works best
  with the fortrabbit MCP server (https://mcp.fortrabbit.com/mcp) and the frbit CLI connected.
  On Windows, rsync needs WSL.
metadata:
  version: "2.9.5"
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

The MCP tools named here and in the references come from the `fortrabbit` server: `list_apps` is `fortrabbit:list_apps`, in Claude Code `mcp__plugin_fortrabbit_fortrabbit__list_apps` or `mcp__fortrabbit__list_apps`.

| Need | MCP (`fortrabbit` server) | frbit CLI | Other |
|---|---|---|---|
| Account, apps, environments, deployments, domains | `get_you`, `list_*`, `get_*` | `frbit <group> list/get --json` | |
| Create an app or environment | `create_app`, `create_environment` | `frbit apps create`, `frbit environments create` (first `frbit regions list`, `frbit plans list --region R --currency EUR --json`, `frbit presets list`; `--dry-run` shows the price; create only after the user agreed) | |
| Environment variables | `get_environment`, `update_environment` | `frbit environments variables get/update` | |
| Branch, build and post-deploy commands | `update_environment` | `frbit environments update` | |
| PHP version | – | `frbit environments create --php-version`, `frbit environments update <env> --php-version` | dashboard |
| Deploy | `create_deployment`, or push to the connected branch | `frbit environments deploy <env>` | deploy hook URL |
| Restart | `restart_environment` | `frbit environments restart <env>` | |
| Why a deployment failed | `get_deployment`, `get_deployment_logs` | `frbit deployments logs <dp>` (`--follow` while it runs) | |
| Workers and cron jobs (queue worker, scheduler) | `create_job`, `list_jobs`, `update_job` | `frbit jobs list/create/update <env or job>`, `frbit jobs delete` after a yes | dashboard |
| Delete | – | `frbit <group> delete`, after a yes | dashboard |
| Pull a database | – | `frbit db pull <env> --output /tmp/` | `ssh` + `mysqldump` ([database.md](references/database.md)) |
| Push a database | – | `frbit db push <file> <env>`, `--confirm <env>` only after a yes | `ssh` + `mysql` ([database.md](references/database.md)) |
| Sync files | – | `frbit files pull <folder> -e <env>`, `frbit files push <folder> -e <env>`, always with a content folder; `--confirm <env>` (push, `--delete`) only after a yes | `rsync` ([files.md](references/files.md)) |
| Remote commands | – | – | `ssh`, `mysql` |
| Runtime logs (PHP, Apache, access, jobs) | `get_environment_logs` | `frbit environments logs <env> --source php --since 1h` | dashboard Logs tab, or log files over SSH |
| Metrics (usage, errors, response times, memory) | `get_environment_metrics` | `frbit environments metrics <env>`, `--metric <slug> --range 7d` | dashboard metrics tab |

Most commands in this table need frbit 1.15.0 or later. An unknown command or flag means an older one: the person upgrades it ([access.md](references/access.md)), or use the Other column.

A `frbit` command fails and the message does not say why: run `frbit doctor --json` (frbit 1.17.0 or later) before anything else. It checks the CLI version against the latest release, the sign-in, `ssh`, `rsync` and `git`, the linked environment and an SSH connection to it, and gives the fix for each failed check. An unknown command means a release without it: upgrade first.

No MCP server and no CLI yet? Connecting takes a few commands: [references/access.md](references/access.md).

No shell, as in claude.ai chat or Cowork: only the MCP column works. Say which steps need a terminal (SSH, database, files), give the person the exact command with IDs filled in to run themselves, and offer the dashboard route where there is one.

## Find the environment

Do not ask for an ID before trying this. Resolve it once per session and reuse it.

1. `git remote get-url origin` → `owner/repo`, and `git branch --show-current`.
2. MCP: `list_git_repositories` → the entry with that `fullName` has `connectedAppPublicId`. `get_app` on it → `region` (e.g. `eu-w1a`) and its `environments`. `list_environments` → of those, the one whose `git.branch` is the current branch. If several match or none does, list the environments by name and ask which one.
3. Without MCP: `frbit link --json` → `environment`, `region` and `sshHost`, from a connected repo, `FORTRABBIT_ENVIRONMENT` or `.fortrabbit/environments.yml` at the repo root (label, usually the branch → environment ID). It fails when nothing resolves: `frbit environments list --json --all`, ask which one, then `frbit link <env>` writes that file; commit it. Every `frbit` command except delete takes the environment as ID or label; read-only ones find it without it, commands that change something need it named, except `db push` and `files`, which `--confirm` guards. Name it anyway; with a label, check the `→ en-…` line on stderr. `--confirm` always takes the `en-` ID, never the label.
4. Derived from that, nothing to store:
   - SSH: `<env>@ssh.<region>.frbit.app` (the CLI prints it as `sshHost`)
   - Default domain: `https://<env>.<region>.frbit.app`. The live URL is the main domain: `list_domains`, `isMain`
   - Database name and user: the environment ID

No MCP tools, or a `401`: connect first ([references/access.md](references/access.md)). No account yet, or no match: the repo is not on fortrabbit yet, see [references/boarding.md](references/boarding.md). A deploy file `.fortrabbit/deploy.yml` (or `.yaml`, `.json`) means the repo deploys to fortrabbit and holds its deployment settings: read it before changing any ([deploy.md](references/deploy.md#deploy-file)). A plain `.fortrabbit` file with `app-env-id=` is a leftover of an older skill and blocks `frbit`: the person deletes it and runs `frbit link <env-id>`.

## References

Load the one file that fits the request, two at most.

| Request | File |
|---|---|
| New to fortrabbit, no account, no app, "host this project" | [boarding.md](references/boarding.md) |
| Move a site from another host (Forge, Ploi, Cloudways, cPanel, a VPS …) | [migrate.md](references/migrate.md) |
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
