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
| `list_jobs` | `environmentPublicId` | `jobs[]` (`publicId`, `name`, `type`, `command`, `isActive`, `exitTimeout`, `exitSignal`, `interval`, `expression`, `maxRuntime`), `limit` (jobs the booked plan allows, 0 when the jobs component is not booked), `count` |
| `get_environment_logs` | `environmentPublicId`, `source` (`php` default, `apache`, `access`, `jobs`), `limit` (1–200, default 50), `since` (ISO 8601 with time zone, or `15m`, `1h`, `7d`), `before`, `status` and `method` (access log only; `status` takes `500`, `5xx` or `500,503`) | `entries[]` newest first (`time`, `level`, `message`, `meta`) and `olderCursor`: pass it as `before` for the next older page, `null` at the end. Kept 14 days. No live tail: ask again with `since` |
| `get_environment_metrics` | `environmentPublicId`, `metric` (a slug such as `php-response-time`, `php-memory`, `error-503`, `traffic`; omit for the summary, whose `metrics` lists the slugs booked for this environment) | Summary: `usage[]` of storage, database and traffic (`current`, `limit`, `percent`, plus readable sizes) and `last24Hours` (requests, 500/503/504 errors, response times, PHP memory peak, out-of-memory kills). With `metric`: that metric over 24 hours, one point per hour. Start here for a slow or failing site, then `get_environment_logs` |
| `list_backups` | `environmentPublicId` | `backups[]` newest first: `status`, `trigger` (scheduled or manual), `createdAt`, `completedAt`, `filesSizeBytes`, `databaseSizeBytes`, `retentionSlot`, `availableUntil`. Needs the backups component |
| `list_teams`, `get_team` | –, `publicId` | teams and the account's role |
| `list_payment_methods`, `get_payment_method` | –, `publicId` | the account's payment methods |

A `list_*` result is an object with one list (`{apps: […]}`; `list_jobs` adds `limit` and `count`). Only `list_deployments` filters and pages; the others return the whole set. `get_environment_logs` pages by cursor.

Writes:

| Tool | Does |
|---|---|
| `create_app` | Creates a trial app and its first environment, with a cloud domain when the name is free; optionally starts the first deployment |
| `create_environment` | Adds an environment to an app without a payment method, with a cloud domain when the name is free |
| `update_environment` | Changes only the fields sent: `name`, `git` (branch, directory), `buildCommands`, `postDeployCommands`, `environmentVariables`, `rootPath` (folder the web server serves; an empty string resets it), `softwareVersion` (major version the software preset supports, from `list_software_presets`) |
| `create_deployment` | Deploys the latest commit of the configured git branch of an environment (`publicId`), replacing the running release and running the post-deploy commands. Cancels a pending or running deployment of that environment. Needs git on the environment; not for client accounts. The result may already be `failed`: `get_deployment`, `get_deployment_logs` |
| `restart_environment` | Restarts the PHP-FPM and worker containers of an environment (`publicId`) without deploying. Queued: `accepted: true` means requested, not finished. Not for client accounts |
| `create_domain` | Adds a domain you own to an environment: `environmentPublicId`, `name`, `isMain` (default false). A bare domain such as `example.com` becomes `www.example.com` plus an apex domain forwarding to it; a subdomain gets no apex. The result lists every created domain with `dns.expected` (`type`, `host`, `value`), `dns.actual` and `dns.status`: show each expected record to the person, who sets it at their DNS provider. Not for client accounts; domains are not deleted over MCP |
| `create_backup` | Requests a manual backup of the files and database of an environment (`environmentPublicId`). Asynchronous: the result is `Pending`, and the backup shows up in `list_backups` when done. Needs the backups component; refused while the environment is offline or a backup or restore runs. Restore stays in the dashboard, download with the frbit CLI |
| `create_job` | Adds a worker or cron job to an environment. Required: `environmentPublicId`, `name`, `command` (starts with `php ` or `bash `), `type` (`worker` runs all the time, `cron` runs on a schedule). A cron job also needs `interval` (`minute`, `hour`, `day`, `custom`) and `maxRuntime` (seconds: 300, 1800, 3600, 10800, 21600), and `expression` (crontab) for `custom`. Optional: `isActive` (default true), `exitTimeout` (1, 5, 10, 30; default 30), `exitSignal` (`TERM`, `INT`; default `TERM`). Needs the jobs component and a free slot (`list_jobs`); not for client accounts |
| `update_job` | Changes only the fields sent on a job: `publicId` (from `list_jobs`), then the optional fields of `create_job`. `type` turns a worker into a cron job or back, and a cron job then needs `interval` and `maxRuntime`. `isActive: false` stops a job without deleting it. Not for client accounts |

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

`update_environment` takes `publicId` plus only the fields to change. `git` is the exception: send `branch` and `directory` together, with `directory` from `get_environment`, because an omitted `directory` resets the source directory to the repository root. With a deploy file, `git` changes are refused: [deploy.md](deploy.md#deploy-file). Environment variables merge: a string adds or changes a variable, `null` removes it, unnamed variables stay. Platform variables (`FORTRABBIT_*`) cannot be changed. Read the current state with `get_environment` first.

MCP neither reads nor sets the PHP version: `frbit environments get --json` shows `phpVersion`, `frbit environments update <env> --php-version <version>` sets it (`frbit php-versions list` has the versions), or the person changes it on the PHP version page of the environment, `https://dash.fortrabbit.com/environments/<env>/php/php-version`. A PHP version set explicitly, also with `frbit environments create --php-version`, opts the environment out of automatic PHP updates: say so.

A changed variable reaches PHP after a restart or the next deployment: `restart_environment` (CLI `frbit environments restart <env>`), `create_deployment`, or push. Ask before either on production.

## Billed changes

MCP refuses every billed change, such as `create_environment` on an app with a payment method. The error message ends with a dashboard link: give the person that link, the change is theirs to make there. With the CLI, run `frbit apps create` or `frbit environments create` with `--dry-run` first: it prints the monthly price, or that it is a trial at no cost, and creates nothing. Show that to the person. Without `--dry-run`, an account without a payment method gets a trial app at once, with no question. With a payment method they print the monthly price and ask before they book anything; without a terminal they stop with `billed change needs --yes`. Run them only after the person agreed, and add `--yes` only after their yes.

## Resources

The person can point at an app or environment instead of describing it:

- `frbit://app/{publicId}`, payload `{publicId, name}`
- `frbit://env/{publicId}`, payload `{publicId, name, appPublicId}` (`appPublicId` is left out when the app is out of scope)

In Claude Code the person writes `@fortrabbit:frbit://env/en-a1b2c3`. Use the `publicId` directly; for detail, call `get_app` or `get_environment`.

## What MCP does not do

| Operation | Route |
|---|---|
| Restore or download a backup | restore in the dashboard, download with `frbit backups download` |
| Scale components, change plans | `frbit environments components update <env> --component SLUG=SIZE` (billed: shows the price and asks first; `--yes` only after the person's yes), or the dashboard |
| Remote commands, database, files | [ssh.md](ssh.md), [database.md](database.md), [files.md](files.md) |
| Delete a job | `frbit jobs delete <job>` after a yes, or the dashboard |
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
| `deployFile: Deployment settings are managed by the deploy file.` | The branch has `.fortrabbit/deploy.yml` (or `.yaml`, `.json`) | Edit the file, commit and push: [deploy.md](deploy.md#deploy-file) |
| `This change is billed to the app's payment method, so it cannot be made over MCP. …` | The change would be billed | Give the person the dashboard link from the message |
| `Error while executing tool` | Unexpected server error | Do not retry blindly or invent arguments; report it and fall back to the dashboard |

Rate limit: about 20 requests per minute per token, shared with the REST API. Batch discovery calls and do not poll `list_*` in a loop. A `429` carries `Retry-After`.
