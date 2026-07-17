# MCP: read and manage apps through the fortrabbit MCP server

fortrabbit exposes a **Model Context Protocol (MCP)** server at
`https://api.fortrabbit.com/mcp`. When an MCP client is configured with a
Public API token, you can query and provision fortrabbit resources directly —
no SSH, no dashboard clicking, no asking the user for IDs you can look up.

Use MCP for **discovery and provisioning**. Keep using the SSH/rsync/deploy-hook
paths for everything MCP does not cover (see "What MCP does not do" below).

---

## Prerequisite — a Public API token

MCP authenticates with the same `frbit-at-…` Bearer token as the `/v1` REST API.
If no MCP server is configured yet, or calls return `401`, set up the token
first: **use the `fortrabbit-api-tokens` skill** (it finds an existing token,
stores it safely, and guides the user to generate one at
`https://dash.fortrabbit.com/you/settings/api-token`).

The token acts as the user and is tenant-scoped to their apps — every MCP call
only ever sees resources the token owner can access.

---

## When to use MCP vs SSH

```
IF the task is: list/inspect apps, environments, deployments, domains, teams,
                payment methods — OR create an app or environment
  → Use MCP (this file)

ELSE IF the task is: deploy, run a remote command, pull/push the database,
                     rsync files/content, read logs, edit env vars, restart
  → Use the SSH/deploy paths (deploy.md, ssh-exec.md, database.md, sync.md,
    sync-content.md) — MCP does not expose these
```

---

## Available MCP tools

Reads (available for any of the user's resources):

| Tool | Returns |
|------|---------|
| `list_apps` / `get_app` | apps: `publicId` (`ap-…`), `name`, `description`, trial flag, payment method |
| `list_environments` / `get_environment` | environments: `publicId` (`en-…`), `name`, `softwareVersion` |
| `list_deployments` / `get_deployment` | deployments: `branch`, `commitHash`, `commitMessage`, `committedAt`, environment |
| `list_domains` / `get_domain` | domains for the user |
| `list_teams` / `get_team` | teams the user belongs to, with their role |
| `list_payment_methods` / `get_payment_method` | the user's payment methods |

Provisioning:

| Tool | Does |
|------|------|
| `create_app` | creates an app **and** its initial environment; can optionally start the first deployment |
| `create_environment` | creates an environment in an app the user can access |

There are intentionally **no** MCP tools for update, restart, deploy trigger, or
standalone deployment creation. Do not assume a tool exists because a dashboard
action does — only the tools above are available.

---

## Discovering the `.fortrabbit` config via MCP

`connect.md` normally has the user copy the app environment ID out of the
dashboard. If MCP is configured, look it up instead:

1. Call `list_apps` (and `list_environments`) and show the user their apps/
   environments by `name`.
2. The environment `publicId` **is** the `app-env-id` for `.fortrabbit` — it is
   the `en-…` value (e.g. `en-wjl0ai`), the same ID used for SSH.
3. Write it to `.fortrabbit`:
   ```
   app-env-id=en-xxxxxx
   region=eu-w1a
   ```

> **Region caveat:** MCP does **not** return the region. Get `region` from the
> user, from `.env` (`FORTRABBIT_REGION`), or from the dashboard — MCP fills in
> `app-env-id`, not `region`. Confirm the region before writing `.fortrabbit`.

---

## Creating an app or environment via MCP

`create_app` provisions the app and its first environment in one call, and can
start the first deployment when the configuration supports it. `create_environment`
adds an environment to an existing app. Before calling either:

- Confirm the intended `name`, `region`, and (for `create_app`) the team and
  payment method with the user — these are billed, real resources.
- Show what you are about to create and get explicit confirmation first.
- After creation, write the returned environment `publicId` to `.fortrabbit`
  (plus the region you used) so the SSH/deploy flows can pick up from there.

---

## What MCP does not do

MCP is for reading and provisioning. It has **no** tools for:

- **Deploying** or triggering a deploy → `deploy.md` (git push / deploy hook)
- **Remote commands** (artisan, craft console, wp-cli) → `ssh-exec.md`
- **Database** pull/push → `database.md`
- **File / content sync** → `sync.md`, `sync-content.md`
- **Logs, HTTP errors, restart, env vars** → dashboard / `http-error-troubleshooting.md`

Two data caveats even for reads:

- **No region** in app/environment payloads (see the region caveat above).
- **No deploy status** — `list_deployments` shows *what* was deployed (branch,
  commit) but not whether it succeeded. For success/failure, check the
  deployment log in the dashboard.

---

## Errors

| Symptom | Meaning | Fix |
|---------|---------|-----|
| `401` | Missing/invalid token | Configure the token — see the `fortrabbit-api-tokens` skill |
| A resource "not found" | It does not belong to the token owner, or the ID is wrong | Confirm the `publicId` via a `list_*` call |
| A write/create is rejected | Provisioning may be gated during rollout | Fall back to the dashboard (`dash.fortrabbit.com/new/app`) |
