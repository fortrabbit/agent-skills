---
applyTo: "**"
---

# fortrabbit — GitHub Copilot Instructions

When helping the user with fortrabbit-related tasks, follow the guidance below.

## What fortrabbit is

[fortrabbit](https://www.fortrabbit.com) is cloud hosting platform for websites and web apps. Apps are deployed via Git push or a deploy hook URL. Remote commands run over SSH exec (no persistent session). Supported PHP frameworks: Laravel, Craft CMS, Kirby, Statamic, WordPress, and generic PHP.

## Configuration lookup

Read config in this order (`.fortrabbit` is the source of truth):

1. Read `.fortrabbit` from the project root first. It uses a simple `key=value` format:
   ```
   app-env-id=en-xxxxxx
   region=eu-w1a
   ```
2. If any value is missing from `.fortrabbit`, supplement from `.env` variables `FORTRABBIT_APP_ENV_ID` and `FORTRABBIT_REGION`.
3. If still missing, ask the user for their app environment ID (format: `en-wjl0ai`) and region (default: `eu-w1a`).
4. If both files define the same key with different values, do not merge silently — ask: "I found two different values for [key]: `[value-a]` (`.fortrabbit`) and `[value-b]` (`.env`). Which is correct?"
5. For deploy hook operations, read `FORTRABBIT_DEPLOY_HOOK_SECRET` from `.env`. Construct the URL as:
   `https://api.fortrabbit.com/webhooks/environments/{app-env-id}/deploy/{secret}`

SSH host pattern: `APP_ENV_ID@ssh.REGION.frbit.app`

## Available operations

| Command      | What it does                                                                                                                                    |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| deploy       | Read `FORTRABBIT_DEPLOY_HOOK_SECRET` from `.env`, construct URL, POST with `User-Agent: fortrabbit`; or remind user to push to their Git remote |
| ssh          | Run a remote command via SSH exec                                                                                                               |
| db pull      | Download remote MySQL database to local                                                                                                         |
| db push      | Upload local MySQL database to remote                                                                                                           |
| content sync | Rsync CMS uploads/content up or down                                                                                                            |
| status       | Show configured environment and detected project type                                                                                           |

## MCP server (optional)

fortrabbit runs an MCP server at `https://api.fortrabbit.com/mcp`. If the user's editor has it connected, prefer it over asking the user for IDs.

- **Connecting** is a one-command browser OAuth flow, e.g. `claude mcp add --transport http fortrabbit https://api.fortrabbit.com/mcp`. A dashboard-issued Public API token (`frbit-at-…`, from https://dash.fortrabbit.com/new/api-token) also works as an `Authorization: Bearer` header for clients without OAuth, and is what scripts and CI should use for the `/v1` REST API.
- **Use it for**: listing/inspecting apps, environments, deployments, domains, teams, payment methods; creating apps and environments; reading deployment logs to diagnose a failed deploy.
- **It does not do**: deploying an existing app, remote commands, database pull/push, file sync, restart, or env vars. Use the SSH and deploy-hook paths for those.
- **Call `get_me` first** — it reports whether the account is a client account (which cannot create environments) and whether a git account is connected.
- **Never guess a public ID or an enumerable value.** Resolve IDs with the matching `list_*` tool (`list_apps`, `list_environments`, …); resolve regions, software presets, PHP versions, component sizes, repositories, and branches with `list_regions`, `list_software_presets`, `list_php_versions`, `list_component_plans`, `list_git_repositories`, `list_git_branches`. Public IDs have the form `xx-nnnnnn`.
- **Filling in `.fortrabbit`**: the environment `publicId` (`en-…`) is the `app-env-id`; `get_app` returns the app's `region`. Confirm both with the user before writing the file.
- **Creating apps and environments is billed.** Show the full configuration, including the monthly price from `list_component_plans`, and get explicit confirmation before calling `create_app` or `create_environment`.

## Project type detection

Check signals in this exact order (first match wins):

```
1. wp-config.php exists OR wp-content/ directory exists → WordPress
2. composer.json contains "craftcms/cms" OR bin/craft exists → Craft CMS
3. composer.json contains "statamic/cms" → Statamic
4. composer.json contains "getkirby/cms" OR site/plugins/ exists → Kirby
5. composer.json contains "laravel/framework" OR artisan file exists at root → Laravel
6. composer.json exists (none of the above) → Generic PHP
7. Nothing found → Ask: "What CMS or framework are you using? (WordPress, Craft CMS, Kirby, Statamic, Laravel, other PHP)"
```

## Safety rules

- Always show the exact SSH command before running it.
- `db push` overwrites the remote database — require explicit user confirmation.
- `db pull` overwrites the local database — warn the user first.
- Never run `DROP DATABASE`, `DROP TABLE`, or `TRUNCATE` without showing the statement and requiring explicit confirmation.
- Never store database passwords in files; use SSH tunnel method only.
- If SSH connection fails, classify the error before acting:
  - `Permission denied (publickey)` → Tell the user their SSH key may not be registered. Direct them to https://dash.fortrabbit.com/you/ssh-keys
  - `Connection timed out` / `Connection refused` / `Network is unreachable` → Tell the user to check (1) internet connection, (2) port 22 not blocked by firewall/VPN, (3) correct region
  - Any other error → Show the full error text and ask what they see

## Gotchas

- **Config conflict**: if `.fortrabbit` and `.env` define the same key with different values, always ask — never silently prefer one over the other.
- **Region default**: when the user hasn't specified a region, default to `eu-w1a` but confirm with them before first use.
- **Deploy hook secret**: the deploy hook URL requires `FORTRABBIT_DEPLOY_HOOK_SECRET` from `.env` — it is never in `.fortrabbit` (no secrets in committed files).
- **No direct DB connections**: database access is exclusively via SSH tunnel. Never attempt a direct remote MySQL connection.
- **SSH port**: fortrabbit uses port 22 exclusively. If `ssh` fails with a timeout, a firewall or VPN blocking port 22 is the most likely cause — not a credentials issue.
- **rsync trailing slashes matter**: omitting or adding a trailing `/` to source paths changes rsync behavior significantly. Always verify the paths before running.

## Response format

Use this structure for every action:

```
I'll [one-sentence description of what you're about to do].

[exact command or commands that will run]

[If destructive only]: This will [describe the impact]. Are you sure you want to proceed?

Result: [outcome of the command]

Next step: [one concrete follow-up suggestion, e.g. "Run migrations locally with `php artisan migrate`"]
```
