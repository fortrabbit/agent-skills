# Boarding: from a project folder to a live app

The person may have no account, no MCP connection and no app yet. Carry the whole flow. Hand over only the steps that need a browser, and check the result yourself instead of waiting for "done".

Connecting, signing in and checking the account:

- Say what you are about to install and why, then wait for a yes.
- Sign-up and sign-in happen in the browser. Never ask for an e-mail address, password or token in the chat. CLI sign-in: [access.md](access.md#sign-in-from-an-agent).
- Call `get_you` (MCP) or run `frbit auth status --json` (CLI) and follow `next` until `ready`.

[www.fortrabbit.com/agents.md](https://www.fortrabbit.com/agents.md) has the same steps for agents without this skill.

Then continue here.

## 1. Look at the project

- The site runs on another host already and you did not come from [migrate.md](migrate.md): start there. It sends you back to step 2.
- `git remote get-url origin` and the current branch. A repo already connected to an app: go back to "Find the environment" in SKILL.md, nothing to create.
- No GitHub remote yet: offer to create one ([git-github.md](git-github.md)), or deploy by rsync instead ([files.md](files.md)).
- `detect_repository_stack` on the repo → `softwareTemplateSlug`. Without a repo, detect locally: [software.md](software.md).

## 2. Create the app

1. `list_regions`, `list_software_templates`, `list_component_plans` with `regionIdentifier` (prices are `null` without it), `list_git_branches`.
   CLI: `frbit regions list`, `frbit plans list --region <id> --currency EUR --json` (`--component <slug>` narrows it; prices are `priceInCents`), `frbit presets list`, `frbit git branches <owner/repo>`. Run them before `frbit apps create`, never guess a region, plan size or software template.
   Check the price with `frbit apps create … --dry-run`: it prints the monthly price, or that the app is a trial at no cost, and creates nothing. Without `--dry-run`, an account without a payment method gets the trial app at once, without a question. With a payment method `apps create` prints the price and asks; without a terminal it stops with `billed change needs --yes`. Run it only after the person agreed to the price, and pass `--yes` only after their yes.
2. Show the name, region, software, components and the **monthly price** after the trial. MCP creates a trial app without a payment method. Wait for a yes.
3. `create_app` with `initialEnvironment.deployment.git` and `startFirstDeployment: true`.
4. `get_deployment` until `status` is `succeeded`, `failed`, `canceled` or `unknown`, `get_deployment_logs` if it failed: [deploy.md](deploy.md).
5. In the project folder, `frbit link`: it confirms the connected repo. Without one, `frbit link <env>` writes `.fortrabbit/environments.yml`; commit it.

Arguments and the environment variant: [mcp.md](mcp.md).

## 3. Database and content

A CMS with existing content needs its database and uploads on the new environment: [database.md](database.md) (push) and [files.md](files.md).

## 4. Close

Tell the person:

- the live URL: the main domain from `list_domains` (`isMain`), usually `https://<label>.frbit.cloud` for a new app
- the dashboard link `https://dash.fortrabbit.com/environments/<env>`
- that a trial app needs a payment method before the trial ends to stay online: `https://dash.fortrabbit.com/new/payment-method`
