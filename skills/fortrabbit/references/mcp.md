# MCP: tools, arguments, provisioning

The fortrabbit MCP server (`https://mcp.fortrabbit.com/mcp`) reads and provisions everything the connected account can access. Not connected yet: [access.md](access.md).

Contents: [Rules](#rules) · [Tools](#tools) · [Resolving arguments](#resolving-arguments) · [Creating an app](#creating-an-app) · [Creating an environment](#creating-an-environment) · [Updating an environment](#updating-an-environment) · [Billed changes](#billed-changes) · [Resources](#resources) · [What MCP does not do](#what-mcp-does-not-do) · [Errors](#errors)

## Rules

1. Call `get_you` first. `client: true` cannot create environments, `gitAccountConnected: false` cannot deploy from git. Follow `next` (`{step, instruction, url}`) until its step is `ready`. `optional` lists steps that are not required, such as `add_ssh_key`: check it before SSH or database work.
2. Every argument has a `list_*` tool behind it. Tool and argument names still say "preset" (`list_software_presets`, `softwarePresetName`); to the person it is the software template. Public IDs match `^[a-z]{2}-[0-9a-z]{6}$`.
3. Writes create trial resources or change live ones. Show what you will send, with the monthly price after the trial for creates, and wait for a yes.

## Tools

Discovery, to resolve values before a write:

| Tool | Arguments | Returns |
|---|---|---|
| `get_you` | – | `publicId`, `email`, `name`, `type`, `client`, `gitAccountConnected`, `gitUsername`, `gitInstallationAccounts`, `next`, `optional` |
| `list_regions` | – | `identifier` (e.g. `eu-w1a`), `name`, `location`, `recommended` |
| `list_software_presets` | – | `slug`, `name`, `versions`, `defaultVersion` |
| `list_component_plans` | `regionIdentifier`, `currency` (`EUR`, `USD`) | per component `slug`, `optional`, `autoscales`, and `sizes[]` with `size`, `name`, `description`, `specs`, `priceInCents`. Without `regionIdentifier` the prices are `null` |
| `list_git_repositories` | – | `owner`, `name`, `fullName`, `defaultBranch`, `private`, `connectedAppPublicId` |
| `list_git_branches` | `repository` (`owner/repo`) | `name`, `protected` |
| `detect_repository_stack` | `repository`, `branch` | `hasComposerJson`, `hasPackageJson`, `nodePackageManager`, `stack`, `softwarePresetSlug` |

Reads:

| Tool | Arguments | Returns |
|---|---|---|
| `list_apps`, `get_app` | –, `publicId` | `get_app`: `region`, `software`, `trial`, `paymentMethod`, `people`, `domains`, `environments` |
| `list_environments`, `get_environment` | –, `publicId` | `name`, `components`, `softwareVersion`, `domains`, `git` (branch, directory), `buildCommands`, `postDeployCommands`; `get_environment` adds `environmentVariables` and `platformVariables` (secrets such as the database password are left out) |
| `list_deployments` | `environmentPublicId`, `limit` (default 20, max 100), `offset` | newest first; `deployments[]` and `total`, the count of all matches |
| `get_deployment` | `publicId` | `environment`, `branch`, `commitHash`, `commitMessage`, `status`, `createdAt`, `committedAt` |
| `get_deployment_logs` | `publicId` | `logs[]` of `{log, time}`: the build and deploy output |
| `list_domains`, `get_domain` | –, `publicId` | custom apex and subdomains, cloud domains (`<label>.frbit.cloud`) and the default domain of every environment. `isMain` marks the live URL |
| `list_teams`, `get_team` | –, `publicId` | teams and the account's role |
| `list_payment_methods`, `get_payment_method` | –, `publicId` | the account's payment methods |

A `list_*` result is an object with one list (`{apps: […]}`). Only `list_deployments` filters and pages; the others return the whole set.

Writes:

| Tool | Does |
|---|---|
| `create_app` | Creates a trial app and its first environment, with a cloud domain when the name is free; optionally starts the first deployment |
| `create_environment` | Adds an environment to an app without a payment method, with a cloud domain when the name is free |
| `update_environment` | Changes only the fields sent: `name`, `git` (branch, directory), `buildCommands`, `postDeployCommands`, `environmentVariables` |

## Resolving arguments

| Argument | Resolve with |
|---|---|
| `region` | `list_regions` → `identifier` |
| `teamPublicId` | `list_teams`; omit for a personal app |
| `appPublicId` | `list_apps` |
| `sourceEnvironmentPublicId` | `list_environments` |
| `softwarePresetName` | `detect_repository_stack`, or `list_software_presets` → `slug` |
| `softwareVersion` | `list_software_presets` → `versions` (major only, e.g. `"11"`) |
| `components` | `list_component_plans` → `slug` and `size` |
| `git.repository` | `list_git_repositories` → `fullName` |
| `git.branch` | `list_git_branches` → `name` |

## Creating an app

`create_app` provisions the app and its first environment in one call. Required: `name`, `region`. Optional: `teamPublicId`, `startFirstDeployment`, and `initialEnvironment` with `softwarePresetName`, `softwareVersion`, `cloudDomain`, `components`, `autoscaling`, `deployment` (`git`, `buildCommands`, `postDeployCommands`).

For a repo that should go live:

1. `get_you`: the account can create, and git is connected.
2. `detect_repository_stack` on the repo → `softwarePresetSlug`.
3. `list_regions`, `list_software_presets`, `list_component_plans` with the region.
4. Show the name, region, software, components, cloud domain and the monthly price after the trial. Wait for a yes.
5. `create_app` with `startFirstDeployment: true`, which needs `initialEnvironment.deployment.git`.
6. `get_deployment` for `status`, `get_deployment_logs` if it failed: [deploy.md](deploy.md).

MCP books nothing billed. The app is a trial without a payment method and is deleted at the end of the trial unless the person adds one in the dashboard.

`cloudDomain` is the label of the cloud domain, e.g. `acme-shop` for `acme-shop.frbit.cloud`. Omitted, it is derived from the app name; none is created when that name is invalid, reserved or taken. The cloud domain becomes the main domain, and the default domain forwards to it.

## Creating an environment

`create_environment` requires `appPublicId` and `name` (3–32 characters, `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`), then one of two paths.

Clone an existing environment, the common case ("add a staging environment like production"):

```text
create_environment(appPublicId: "ap-a1b2c3", name: "staging", sourceEnvironmentPublicId: "en-wjl0ai")
```

Or set `components` explicitly. Required slugs: `php`, `storage`, `traffic`, `backups`. Optional slugs, `off` by default: `database`, `jobs`, `key-value-store`. Values are size keys from `list_component_plans`, or `"off"`:

```text
components: {"php": "xs", "storage": "xs", "traffic": "xs", "backups": "xs", "database": "sm"}
```

Also optional: `git` (branch, directory), `buildCommands`, `postDeployCommands`, `environmentVariables`, `softwareVersion` (defaults to the app's), `autoscaling`, `cloudDomain` (derived from the app's cloud domain and the environment name, e.g. `acme-shop-staging`), and `startFirstDeployment`, which needs `git`.

## Updating an environment

`update_environment` takes `publicId` plus only the fields to change. Environment variables merge: a string adds or changes a variable, `null` removes it, unnamed variables stay. Platform variables (`FORTRABBIT_*`) cannot be changed. Read the current state with `get_environment` first.

MCP neither reads nor sets the PHP version: `frbit environments get --json` shows `phpVersion`, and the person changes it on the PHP version page of the environment, `https://dash.fortrabbit.com/environments/<env>/php/php-version`. A PHP version set explicitly, also with `frbit environments create --php-version`, opts the environment out of automatic PHP updates: say so.

A changed variable reaches PHP after a restart or the next deployment: `frbit environments restart <env>`, or push. Ask before either on production.

## Billed changes

MCP refuses every billed change, such as `create_environment` on an app with a payment method. The error message ends with a dashboard link: give the person that link, the change is theirs to make there. With the CLI, `frbit environments create` works too, after the person confirmed the monthly price.

## Resources

The person can point at an app or environment instead of describing it:

- `frbit://app/{publicId}`, payload `{publicId, name}`
- `frbit://env/{publicId}`, payload `{publicId, name, appPublicId}` (`appPublicId` is left out when the app is out of scope)

In Claude Code the person writes `@fortrabbit:frbit://env/en-a1b2c3`. Use the `publicId` directly; for detail, call `get_app` or `get_environment`.

## What MCP does not do

| Operation | Route |
|---|---|
| Deploy an existing environment | push to the connected branch, or `frbit environments deploy <env>`: [deploy.md](deploy.md) |
| Restart an environment | `frbit environments restart <env>` |
| Scale components, change plans | dashboard |
| Remote commands, database, files | [ssh.md](ssh.md), [database.md](database.md), [files.md](files.md) |
| Runtime logs | dashboard Logs tab: [troubleshooting.md](troubleshooting.md) |
| Delete an app, environment, domain or team | `frbit <group> delete` after a yes, or the dashboard |
| Read or change the PHP version | CLI or dashboard, see "Updating an environment" |
| Anything billed | the dashboard link from the error, see "Billed changes" |

## Errors

A tool failure comes back as a normal result with `isError: true` and a plain-text message that says what to fix.

| Message | Meaning | Fix |
|---|---|---|
| `401` with `WWW-Authenticate` | Not connected, or the sign-in expired | Re-run the sign-in: [access.md](access.md) |
| `App not found.` (or environment, deployment, domain, team, payment method) | The ID is wrong or belongs to someone else; the two look the same on purpose | Re-resolve with the matching `list_*` tool |
| `Access denied.` | Signed in, but not permitted for this resource or account type | Check `get_you`: client accounts cannot create environments |
| `Invalid arguments. <field>: <message>` | Validation failed | Fix the named field with the tool from "Resolving arguments" |
| `components: No plan supplied for component php. …` | A required component is missing | Supply `php`, `storage`, `traffic`, `backups`, or clone with `sourceEnvironmentPublicId` |
| `Deployment settings are managed by the deploy file.` | The branch has `.fortrabbit/deploy.yml` (or `.yaml`, `.json`) | Edit the file, commit and push: [deploy.md](deploy.md#deploy-file) |
| `This change is billed to the app's payment method, so it cannot be made over MCP. …` | The change would be billed | Give the person the dashboard link from the message |
| `Error while executing tool` | Unexpected server error | Do not retry blindly or invent arguments; report it and fall back to the dashboard |

Rate limit: about 20 requests per minute per token, shared with the REST API. Batch discovery calls and do not poll `list_*` in a loop. A `429` carries `Retry-After`.
