# Deploying

A deployment builds the latest commit of the connected branch, copies it into the environment and runs the post deploy commands. It never deploys from the local working copy: only what is pushed to GitHub counts.

## Before deploying

1. Find the environment (SKILL.md) and check its `git` settings: repository and branch.
2. `git status --porcelain` and `git log origin/<branch>..HEAD`: uncommitted or unpushed work does not deploy. Ask whether to commit and push it.
3. Not connected to a repo (`git` empty, `gitAccountConnected: false`): [git-github.md](git-github.md), or deploy without git by rsync: [files.md](files.md).

## Trigger

| Situation | How |
|---|---|
| Push to deploy (default) | `git push origin <branch>`. The fortrabbit GitHub App starts the deployment. |
| Manual trigger, or redeploy the same commit with changed settings | `frbit environments deploy <env>` |
| From CI or a CMS publish event | Deploy hook, set up by the person (below) |

Show the commands and ask before running them. One yes can cover commit, push and deploy when all three were shown together. An older commit cannot be redeployed: revert it in git and push.

The deploy hook URL is a secret: anyone who has it can deploy. The person enables it in the dashboard under Deployment → Deploy hook and stores it as a CI secret, never in a committed file. The agent does not call it; it deploys with `frbit environments deploy`. For the person's CI step:

```shell
curl -X POST "$FORTRABBIT_DEPLOY_HOOK_URL" -H "User-Agent: fortrabbit"
```

It answers `202` with the deployment ID, or `404` for a wrong or revoked URL.

## Follow the deployment

1. `list_deployments` with `environmentPublicId` and `limit: 1` → the newest deployment of the environment, or the ID from `frbit environments deploy --json`. CLI: `frbit deployments list --environment <en>` (CLI 1.11.0 or later).
2. `get_deployment` → `status`: `pending`, `started`, `preparing`, `building` and `distributing` mean it still runs; it ends as `succeeded`, `failed` or `canceled`. `unknown` means the platform lost track of it: check the site and the log, then deploy again if needed. Check again after 20–30 seconds while it runs; do not poll faster.
3. Failed: `get_deployment_logs` (or `frbit deployments logs <dp>`). Quote the failing lines to the person.
4. Done: check the site, see "Is it live?" in [troubleshooting.md](troubleshooting.md).

## Why deployments fail

| Log shows | Cause | Fix |
|---|---|---|
| Composer error | `composer.lock` out of sync, a private package, a PHP version mismatch | `composer install` locally, commit the lock file; compare the PHP version in the dashboard with `composer.json` |
| Build command error (`npm run build` …) | Missing dependency or script | Reproduce locally with the same command |
| Post deploy command failed | Migration or cache command broke | The new code is **already live**. Fix and push again, or run the command over SSH: [ssh.md](ssh.md) |
| Nothing happens after a push | Pushed to a branch that is not connected, or the trigger is manual | Compare the branch with `git.branch`; use `frbit environments deploy` |

## Build and post deploy commands

Read them with `get_environment` (`buildCommands`, `postDeployCommands`), change them with `update_environment` or `frbit environments update`. The software templates set defaults, such as `php artisan migrate --force` for Laravel, and `php craft migrate/all`, `php craft project-config/apply` for Craft CMS: see [software.md](software.md). A deploy file `.fortrabbit/deploy.yml` in the repo overrides the dashboard settings; then edit the file, not the environment.
