# MCP: tools, arguments, provisioning

The fortrabbit MCP server (`https://mcp.fortrabbit.com/mcp`) reads and provisions everything the connected account can access. Not connected yet: [access.md](access.md).

## Rules

1. Call `get_you` first: `client: true` cannot create environments, `gitAccountConnected: false` cannot deploy from git. Follow `next` (`{step, instruction, url}`) until its step is `ready`.
2. Never guess a public ID (`^[a-z]{2}-[0-9a-z]{6}$`) or an enumerable value. Every argument has a `list_*` tool behind it.
3. An app or environment attached to the conversation (`@fortrabbit:fortrabbit://environment/en-…`) carries its `publicId`: use it directly.
4. Writes create billed resources or change live ones. Show what you will send, with the monthly price for creates, and wait for a yes.

## Tool catalogue

### Discovery — resolve values before a write

| Tool | Arguments | Returns |
|------|-----------|---------|
| `get_you` | — | `publicId`, `email`, `name`, `type`, `active`, `client`, `gitAccountConnected`, `gitUsername`, `gitInstallationAccounts` |
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
| `list_environments` / `get_environment` | — / `publicId` | `name`, `components`, `phpVersion`, `softwareVersion`, `domains`, `git` (branch, directory), `buildCommands`, `postDeployCommands`; `get_environment` adds `environmentVariables` and `platformVariables` (secrets such as the database password are left out) |
| `list_deployments` / `get_deployment` | — / `publicId` | branch, commit, state |
| `get_deployment_logs` | `publicId` | `logs[]` of `{log, time}` — the build and deploy output |
| `list_domains` / `get_domain` | — / `publicId` | includes custom apex/subdomains **and** the default domain of every environment |
| `list_teams` / `get_team` | — / `publicId` | teams and the account's role |
| `list_payment_methods` / `get_payment_method` | — / `publicId` | the account's payment methods |

Every `list_*` returns a single-key wrapper object (`{apps: […]}`), not a bare
array, and returns the **whole** scoped set — there are no filter, sort, or limit
arguments.

### Writes

| Tool | Does |
|------|------|
| `create_app` | Creates a trial app **and** its initial environment; optionally starts the first deployment |
| `create_environment` | Adds an environment to an app the account can access, unless the app has a payment method |
| `update_environment` | Changes only the fields you send: `name`, `git` (branch, directory), `buildCommands`, `postDeployCommands`, `phpVersion`, `environmentVariables` |

There are no tools for restart, standalone deploy or delete: see "What MCP does not do".

---

## Resolving arguments before a write

Every write argument has a discovery tool behind it. Resolve, never guess:

| Argument | Resolve with |
|----------|--------------|
| `region` | `list_regions` → `identifier` |
| `teamPublicId` | `list_teams` (omit for a personal app) |
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

Required: `name`, `region`. Optional: `teamPublicId`,
`startFirstDeployment`, and a nested `initialEnvironment` object
(`softwarePresetName`, `softwareVersion`, `components`, `autoscaling`,
`deployment.git`).

Recommended sequence for a repo that should go live:

1. `get_you` — confirm the account can create, and that git is connected.
2. `detect_repository_stack` on the user's repo → `softwarePresetSlug`.
3. `list_regions`, `list_software_presets`, `list_component_plans <region>`.
4. Show the user the exact name, region, preset, components, and **monthly
   price**, and get explicit confirmation.
5. `create_app` with `startFirstDeployment: true` (requires
   `initialEnvironment.deployment.git`).
6. `get_deployment` for state; `get_deployment_logs` if it failed.

> MCP books nothing billed. `create_app` creates a trial app without a payment
> method; it is deleted at the end of the trial unless the person adds one in the
> dashboard. Still show what you are about to create, with the monthly price after
> the trial, and wait for explicit confirmation before calling a write tool.

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

On an app with a payment method (`get_app` → `paymentMethod`), `create_environment`
is refused, because the new environment would be billed. See "Billed changes" below.

---

## Updating an environment

`update_environment` takes `publicId` plus only the fields to change. Environment variables merge: a string value adds or changes a variable, `null` removes it, unnamed variables stay. Platform variables (`FORTRABBIT_*`) cannot be changed. Call `get_environment` first to see `environmentVariables` and `platformVariables`.

On an app with a payment method, a `phpVersion` with a surcharge (`list_php_versions` → `surcharge`) is refused, unless the environment runs it already. See "Billed changes" below.

A changed variable reaches PHP after a restart or the next deployment: `frbit environments restart <env>`, or push. Ask before both on production.

---

## Billed changes

MCP refuses every change that is billed: `create_environment` on an app with a payment method, and a `phpVersion` with a surcharge on such an app. The error message ends with a dashboard link. Give the person that link: the change is theirs to make there. With the CLI available, `frbit environments create` works too, after the person confirmed the monthly price.

---

## Resources — letting the user point at an app

The server publishes two resource templates so the user can name a resource
instead of describing it:

- `fortrabbit://app/{publicId}` — payload `{publicId, name}`
- `fortrabbit://environment/{publicId}` — payload `{publicId, name, appPublicId}`
  (`appPublicId` is omitted when the owning app is out of scope)

In Claude Code the user writes `@fortrabbit:fortrabbit://app/ap-a1b2c3`. Payloads are
identity-only by design — they tell you *which* resource is meant. For detail,
call `get_app` / `get_environment`.

---

## What MCP does not do

| Operation | Route |
|-----------|-------|
| Deploy an existing environment | push to the connected branch, or `frbit environments deploy <env>`: [deploy.md](deploy.md) |
| Restart an environment | `frbit environments restart <env>` |
| Scale components, change plans | dashboard |
| Remote commands, database, files | [ssh.md](ssh.md), [database.md](database.md), [files.md](files.md) |
| Runtime logs | dashboard Logs tab: [troubleshooting.md](troubleshooting.md) |
| Delete an app, environment, domain or team | `frbit <group> delete` after a yes, or the dashboard |
| Anything billed: an environment on an app with a payment method, a PHP version with a surcharge | the dashboard link from the error: see "Billed changes" |

---

## Errors

Tool failures come back as a normal result with `isError: true` and a plain-text
message. Read the message — it is written to be self-correcting.

| Message | Meaning | Fix |
|---------|---------|-----|
| `401` + `WWW-Authenticate: …` | Not connected, or the OAuth token expired | See [access.md](access.md); re-run the OAuth flow |
| `App not found.` (or `Environment` / `Deployment` / `Domain` / `Team` / `Payment method`) | The ID is wrong **or** belongs to someone else — deliberately indistinguishable | Re-resolve with the matching `list_*` call |
| `Access denied.` | Authenticated, but not permitted for this resource or account type | Check `get_you` — client accounts cannot create environments |
| `Invalid arguments. <field>: <message>` | Validation failed | Fix the named field; resolve its value with the tool from the table above |
| `components: No plan supplied for component php. Supply a size key for every required component.` | Missing a required component | Supply `php`, `storage`, `traffic`, `backups` — or set `sourceEnvironmentPublicId` to clone |
| `This change is billed to the app's payment method, so it cannot be made over MCP. …` | The change would be billed | Give the person the dashboard link at the end of the message: see "Billed changes" |
| `Error while executing tool` (no detail) | An unexpected server-side error | Do not retry blindly or invent arguments; report it and fall back to the dashboard |

**Rate limit:** roughly 20 requests per minute per connection. Batch your
discovery calls — do not poll `list_*` in a loop. A `429` carries `Retry-After`.
