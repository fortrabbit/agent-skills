# Git and GitHub

A GitHub repo maps to an app, a branch to an environment. Pushes to the connected branch deploy through the fortrabbit GitHub App.

## Check what exists

```shell
git rev-parse --git-dir && git remote get-url origin && git branch --show-current
gh auth status          # GitHub CLI, optional but handy
```

Then `get_you`: `gitAccountConnected` and `gitInstallationAccounts` (the GitHub accounts and organizations the app is installed on). `list_git_repositories` shows which repos fortrabbit can see and which app each one is connected to.

## No repo yet

Ask before creating anything on GitHub.

```shell
git init && git add -A && git commit -m "Initial commit"
gh repo create <name> --private --source=. --remote=origin --push
```

Check `.gitignore` first: `.env`, `vendor/`, `node_modules/` and upload folders stay out of git.

## Install the fortrabbit GitHub App

Needed once per GitHub account or organization. The person installs it at `https://github.com/apps/fortrabbit` (or during sign-up with GitHub), picks the account and grants the repos. Then call `get_you` again to confirm instead of waiting for "done". A repo of an organization appears only after the app is installed on that organization.

## Connect the repo

- New app: `create_app` with `initialEnvironment.deployment.git` (repository and branch): [mcp.md](mcp.md).
- New environment for another branch, e.g. staging: `create_environment` with `git`.
- Change the branch of an existing environment: `update_environment` with `git`, after a yes. The next push to that branch deploys.

Then deploy: [deploy.md](deploy.md).

## Notes

- Every push to the connected branch deploys, whoever pushed it. The person can limit that to app developers with the deployment permission setting in the dashboard.
- Uninstalling the GitHub App on GitHub stops all deployments of the connected apps.
