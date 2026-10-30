# Boarding: from a project folder to a live app

The person may have no account, no MCP connection and no app yet. Carry the whole flow. Hand over only the steps that need a browser, and check the result yourself instead of waiting for "done".

Connecting, signing in and checking the account:

- Ask before installing anything, the `frbit` CLI included, and show the install command first.
- Sign-up and sign-in happen in the browser. Never ask for an e-mail address, password or token in the chat. CLI sign-in: [access.md](access.md#sign-in-from-an-agent).
- Call `get_you` (MCP) or run `frbit auth status --json` (CLI) and follow `next` until `ready`.

[www.fortrabbit.com/agents.md](https://www.fortrabbit.com/agents.md) has the same steps for agents without this skill.

Then continue here.

## 1. Look at the project

- `git remote get-url origin` and the current branch. A repo already connected to an app: go back to "Find the environment" in SKILL.md, nothing to create.
- No GitHub remote yet: offer to create one ([git-github.md](git-github.md)), or deploy by rsync instead ([files.md](files.md)).
- `detect_repository_stack` on the repo → `softwarePresetSlug`. Without a repo, detect locally: [software.md](software.md).

## 2. Create the app

1. `list_regions`, `list_software_presets`, `list_component_plans` with `regionIdentifier` (prices are `null` without it), `list_git_branches`.
2. Show the name, region, software, components and the **monthly price** after the trial. MCP creates a trial app without a payment method. Wait for a yes.
3. `create_app` with `initialEnvironment.deployment.git` and `startFirstDeployment: true`.
4. `get_deployment` until `status` is `succeeded`, `failed`, `canceled` or `unknown`, `get_deployment_logs` if it failed: [deploy.md](deploy.md).

Arguments and the environment variant: [mcp.md](mcp.md).

## 3. Database and content

A CMS with existing content needs its database and uploads on the new environment: [database.md](database.md) (push) and [files.md](files.md).

## 4. Close

Tell the person:

- the live URL: the main domain from `list_domains` (`isMain`), usually `https://<label>.frbit.cloud` for a new app
- the dashboard link `https://dash.fortrabbit.com/environments/<env>`
- that a trial app needs a payment method before the trial ends to stay online: `https://dash.fortrabbit.com/new/payment-method`
