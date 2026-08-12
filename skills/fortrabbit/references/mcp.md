# MCP: discover, provision, and diagnose apps through the fortrabbit MCP server

fortrabbit exposes a **Model Context Protocol** server at
`https://api.fortrabbit.com/mcp` (streamable HTTP). Once a client is connected,
you can read and provision fortrabbit resources directly — no SSH, no dashboard
clicking, no asking the user for IDs you can look up.

Use MCP for **discovery, provisioning, and deployment diagnosis**. Keep using
the SSH/rsync/deploy-hook paths for everything MCP does not cover (see "What MCP
does not do").

---

## Prerequisite — a connected client

If no fortrabbit MCP server is configured, or calls return `401`, **use the
`fortrabbit-api-access` skill**. The short version:

```sh
claude mcp add --transport http fortrabbit https://api.fortrabbit.com/mcp
```

This runs a browser OAuth flow — the user approves, and no token is ever handled
by you. Dashboard-issued `frbit-at-…` Public API tokens are also accepted as a
Bearer header for clients without OAuth support.

Every call is tenant-scoped: you only ever see resources the connected account
can access.

---

## Four rules that prevent most failures

1. **Call `get_me` first.** It reports whether the account is a *client* account
   (clients cannot create environments) and whether a git account is connected.
2. **Never guess a public ID.** Resolve it with the matching `list_*` tool. All
   public IDs have the form `xx-nnnnnn` (`^[a-z]{2}-[0-9a-z]{6}$`).
3. **Never guess an enumerable value either.** Regions, software presets, PHP
   versions, component sizes, repositories, and branches each have a `list_*`
   tool. A guessed value fails validation.
4. **If an app or environment resource is attached to the conversation, use the
   `publicId` from its payload directly** — do not re-resolve it through
   `list_apps` / `list_environments`.

---

## When to use MCP vs SSH

```
IF the task is: list/inspect apps, environments, deployments, domains, teams,
                payment methods — OR create an app or environment
                — OR find out why a deployment failed
  → Use MCP (this file)

ELSE IF the task is: deploy an existing app, run a remote command, pull/push the
                     database, rsync files/content, edit env vars, restart
  → Use the SSH/deploy paths (deploy.md, ssh-exec.md, database.md, sync.md,
    sync-content.md) — MCP does not expose these
```

---

## Tool catalogue

### Discovery — resolve values before a write

| Tool | Arguments | Returns |
|------|-----------|---------|
| `get_me` | — | `publicId`, `email`, `name`, `type`, `active`, `client`, `gitAccountConnected`, `gitUsername`, `gitInstallationAccounts` |
| `list_regions` | — | `identifier` (e.g. `eu-w1a`), `name`, `location`, `recommended` |
| `list_software_presets` | — | `slug`, `name`, `versions`, `defaultVersion` |
| `list_php_versions` | — | `version`, `eol`, `default` |
| `list_component_plans` | `regionIdentifier?`, `currency?` (`EUR`\|`USD`) | per component: `slug`, `optional`, `autoscales`, and `sizes[]` with `size`, `name`, `description`, `specs`, `priceInCents` |
| `list_git_repositories` | — | `owner`, `name`, `fullName`, `defaultBranch`, `private`, `connectedAppPublicId` |
| `list_git_branches` | `repository` (`"owner/repo"`) | `name`, `protected` |
| `detect_repository_stack` | `repository`, `branch?` | `hasComposerJson`, `hasPackageJson`, `nodePackageManager`, `stack`, `softwarePresetSlug` |

> `list_component_plans` returns `priceInCents: null` unless you pass
> `regionIdentifier`. Pass it whenever you intend to show the user a price.

### Reads

| Tool | Arguments | Notes |
|------|-----------|-------|
| `list_apps` / `get_app` | — / `publicId` | `get_app` returns `region`, `software`, `phpVersion`, `trial`, `paymentMethod`, `people`, `domains`, `environments` |
| `list_environments` / `get_environment` | — / `publicId` | returns `state`, `components`, `phpVersion`, `softwareVersion`, `domains` |
| `list_deployments` / `get_deployment` | — / `publicId` | branch, commit, state |
| `get_deployment_logs` | `publicId` | `logs[]` of `{log, time}` — the build and deploy output |
| `list_domains` / `get_domain` | — / `publicId` | includes custom apex/subdomains **and** the generated environment URL of every environment |
| `list_teams` / `get_team` | — / `publicId` | teams and the account's role |
| `list_payment_methods` / `get_payment_method` | — / `publicId` | the account's payment methods |

Every `list_*` returns a single-key wrapper object (`{apps: […]}`), not a bare
array, and returns the **whole** scoped set — there are no filter, sort, or limit
arguments.

### Writes

| Tool | Does |
|------|------|
| `create_app` | Creates an app **and** its initial environment; optionally starts the first deployment |
| `create_environment` | Adds an environment to an app the account can access |

There are intentionally **no** tools for update, restart, deploy trigger, or
standalone deployment creation. Do not assume a tool exists because a dashboard
action does.

---

## Resolving arguments before a write

Every write argument has a discovery tool behind it. Resolve, never guess:

| Argument | Resolve with |
|----------|--------------|
| `region` | `list_regions` → `identifier` |
| `teamPublicId` | `list_teams` (omit for a personal app) |
| `paymentMethodPublicId` | `list_payment_methods` |
| `appPublicId` | `list_apps` |
| `sourceEnvironmentPublicId` | `list_environments` |
| `softwarePresetName` | `detect_repository_stack`, or `list_software_presets` → `slug` |
| `softwareVersion` | `list_software_presets` → `versions` (major only, e.g. `"11"`) |
| `phpVersion` | `list_php_versions` → `version` (e.g. `"8.4"`) |
| `components` | `list_component_plans` → `slug` + `size` |
| `git.repository` | `list_git_repositories` → `fullName` (`"owner/repo"`) |
| `git.branch` | `list_git_branches` → `name` |
| why it failed | `get_deployment` → `state`, then `get_deployment_logs` |

---

## Creating an app

`create_app` provisions the app and its first environment in one call.

Required: `name`, `region`. Optional: `teamPublicId`, `paymentMethodPublicId`,
`startFirstDeployment`, and a nested `initialEnvironment` object
(`softwarePresetName`, `softwareVersion`, `components`, `autoscaling`,
`deployment.git`).

Recommended sequence for a repo that should go live:

1. `get_me` — confirm the account can create, and that git is connected.
2. `detect_repository_stack` on the user's repo → `softwarePresetSlug`.
3. `list_regions`, `list_software_presets`, `list_component_plans <region>`.
4. Show the user the exact name, region, preset, components, and **monthly
   price**, and get explicit confirmation.
5. `create_app` with `startFirstDeployment: true` (requires
   `initialEnvironment.deployment.git`).
6. `get_deployment` for state; `get_deployment_logs` if it failed.

> These are billed, real resources. Always show what you are about to create and
> wait for explicit confirmation before calling a write tool.

---

## Creating an environment

`create_environment` requires `appPublicId` and `name` (3–32 chars,
`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`). Then **one of two paths**:

**Clone an existing environment** — the common case ("add a staging environment
like production"). No `components` argument needed at all:

```
create_environment(appPublicId: "ap-a1b2c3", name: "staging",
                   sourceEnvironmentPublicId: "en-wjl0ai")
```

**Or specify components explicitly.** Required slugs: `php`, `storage`,
`traffic`, `backups`. Optional slugs, which default to `off`: `database`,
`jobs`, `key-value-store`. Values are size keys from `list_component_plans`
(e.g. `"xs"`, `"sm"`), or `"off"` to disable an optional one:

```
components: {"php": "xs", "storage": "xs", "traffic": "xs",
             "backups": "xs", "database": "sm"}
```

`autoscaling` defaults to `true`. `softwareVersion` defaults to the app's;
`get_app` reports the app's region and software preset, which constrain it.

---

## Writing `.fortrabbit` from MCP

`connect.md` normally has the user copy values out of the dashboard. With MCP
you can resolve **both** fields:

1. `list_apps` / `list_environments` — show the user their apps by `name`.
2. The environment `publicId` (`en-…`) is the `app-env-id`, the same ID used
   for SSH.
3. `get_app` returns the app's `region` — use its identifier (e.g. `eu-w1a`),
   the same format `list_regions` reports.
4. Confirm both with the user, then write:
   ```
   app-env-id=en-xxxxxx
   region=eu-w1a
   ```

---

## Resources — letting the user point at an app

The server publishes two resource templates so the user can name a resource
instead of describing it:

- `fortrabbit://app/{publicId}` — payload `{publicId, name}`
- `fortrabbit://environment/{publicId}` — payload `{publicId, name, appPublicId}`
  (`appPublicId` is omitted when the owning app is out of scope)

In Claude Code the user writes `@fortrabbit:app/ap-a1b2c3`. Payloads are
identity-only by design — they tell you *which* resource is meant. For detail,
call `get_app` / `get_environment`.

---

## What MCP does not do

MCP covers reading, provisioning, and deployment diagnosis. It has **no** tools
for:

- **Deploying an existing app** or triggering a deploy → `deploy.md`
  (deployment happens only as a side effect of `create_app` /
  `create_environment`)
- **Remote commands** (artisan, craft console, wp-cli) → `ssh-exec.md`
- **Database** pull/push → `database.md`
- **File / content sync** → `sync.md`, `sync-content.md`
- **Restart, env vars, scaling changes** → dashboard
- **Runtime HTTP errors** → `http-error-troubleshooting.md`

---

## Errors

Tool failures come back as a normal result with `isError: true` and a plain-text
message. Read the message — it is written to be self-correcting.

| Message | Meaning | Fix |
|---------|---------|-----|
| `401` + `WWW-Authenticate: …` | Not connected, or the OAuth token expired | Use the `fortrabbit-api-access` skill; re-run `claude mcp add` |
| `App not found.` (or `Environment` / `Deployment` / `Domain` / `Team` / `Payment method`) | The ID is wrong **or** belongs to someone else — deliberately indistinguishable | Re-resolve with the matching `list_*` call |
| `Access denied.` | Authenticated, but not permitted for this resource or account type | Check `get_me` — client accounts cannot create environments |
| `Invalid arguments. <field>: <message>` | Validation failed | Fix the named field; resolve its value with the tool from the table above |
| `components: No plan supplied for component php. Supply a size key for every required component.` | Missing a required component | Supply `php`, `storage`, `traffic`, `backups` — or set `sourceEnvironmentPublicId` to clone |
| `Error while executing tool` (no detail) | An unexpected server-side error | Do not retry blindly or invent arguments; report it and fall back to the dashboard |

**Rate limit:** roughly 20 requests per minute per connection. Batch your
discovery calls — do not poll `list_*` in a loop. A `429` carries `Retry-After`.
