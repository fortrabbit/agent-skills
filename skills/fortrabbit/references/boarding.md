# Boarding: from a project folder to a live app

The person may have no account, no MCP connection and no app yet. Carry the whole flow. Hand over only the steps that need a browser, and check the result yourself instead of waiting for "done".

## 1. Connect the agent

If the fortrabbit MCP tools are not available, ask before installing, then run:

```shell
frbit setup agent          # skills plus MCP server, when the CLI is installed
claude mcp add --transport http fortrabbit https://mcp.fortrabbit.com/mcp   # MCP only
```

Other clients: [access.md](access.md). Restart the agent session if the client asks for it.

## 2. Sign up or sign in, in the browser

The first MCP call opens the fortrabbit login page in the browser. The person signs up there (GitHub, Google, GitLab or e-mail) or signs in, verifies the e-mail address, and approves the connection. Tell them it's their step. Never ask for an e-mail address, password or token in the chat.

## 3. Check the account

Call `get_you`. It reports:

- `client: true`: a client account, which cannot create environments. Someone with a developer account has to create them.
- `gitAccountConnected: false`: git deployment needs the fortrabbit GitHub App: [git-github.md](git-github.md).

If a check fails, give the person the link, then call `get_you` again before moving on.

## 4. Look at the project

- `git remote get-url origin` and the current branch. A repo already connected to an app: go back to "Find the environment" in SKILL.md, nothing to create.
- No GitHub remote yet: offer to create one ([git-github.md](git-github.md)), or deploy by rsync instead ([files.md](files.md)).
- `detect_repository_stack` on the repo → `softwarePresetSlug`. Without a repo, detect locally: [software.md](software.md).

## 5. Create the app

1. `list_regions`, `list_software_presets`, `list_component_plans` with `regionIdentifier` (prices are `null` without it), `list_git_branches`.
2. Show the name, region, software, components and the **monthly price**. Mention the free trial when `get_app` later reports `trial`. Wait for a yes: this is a billed resource.
3. `create_app` with `initialEnvironment.deployment.git` and `startFirstDeployment: true`.
4. `get_deployment` until the state settles, `get_deployment_logs` if it failed: [deploy.md](deploy.md).

Arguments and the environment variant: [mcp.md](mcp.md).

## 6. Database and content

A CMS with existing content needs its database and uploads on the new environment: [database.md](database.md) (push) and [files.md](files.md).

## 7. Close

Tell the person:

- the live URL `https://<env>.<region>.frbit.app`
- the dashboard link `https://dash.fortrabbit.com/environments/<env>`
- that a trial app needs a payment method before the trial ends to stay online: `https://dash.fortrabbit.com/new/payment-method`
