# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**fortrabbit/agent-skills** is a multi-platform AI skills package for managing PHP web applications hosted on fortrabbit. It ships instructional content consumed by Claude Code, OpenAI Codex, and GitHub Copilot — there is no build step, no compiled code, and no tests.

## Architecture

The project provides the same operational guidance in platform-specific formats:

| File / Path                                       | Platform                                             |
| ------------------------------------------------- | ---------------------------------------------------- |
| `skills/fortrabbit/SKILL.md`                      | Claude Code + OpenAI Codex (canonical source)        |
| `skills/fortrabbit-api-tokens/SKILL.md`           | Claude Code + OpenAI Codex — Public API/MCP token setup |
| `AGENTS.md`                                       | OpenAI Codex contributor context (mirrors this file) |
| `.github/instructions/fortrabbit.instructions.md` | GitHub Copilot                                       |

`skills/fortrabbit/SKILL.md` is the canonical source. When updating operational guidance, propagate changes to `.github/instructions/fortrabbit.instructions.md`.

### Skill reference files

`skills/fortrabbit/references/` contains operation guides loaded contextually by `SKILL.md`. Each file must cover all six supported frameworks:

- `start.md` — onboarding / first-run Q&A
- `connect.md` — fortrabbit onboarding: account, app, SSH key, connection test
- `mcp.md` — using the fortrabbit MCP server (`api.fortrabbit.com/mcp`) to discover and provision apps/environments; token setup via the `fortrabbit-api-tokens` skill
- `ssh-key-setup.md` — SSH key generation and dashboard registration
- `setup-git-github.md` — Git and GitHub setup for deployments
- `deploy.md` — Git push and deploy hook workflows
- `ssh-exec.md` — Remote command syntax per framework
- `database.md` — SSH tunnel setup and DB pull/push procedures
- `sync-content.md` — Per-framework rsync paths and examples
- `sync.md` — Full file sync via rsync (no-Git fallback)
- `browser-review.md` — Reviewing changes on the fortrabbit test domain
- `software-detection.md` — Detecting installed software / CMS
- `local-development.md` — Detecting local dev tooling / dev container setup
- `craft-cms.md` — Craft CMS config for local and fortrabbit environments
- `kirby-cms.md` — Kirby config for local and fortrabbit environments
- `wordpress.md` — WordPress config for local and fortrabbit environments
- `statamic.md` — Statamic config for local and fortrabbit environments

### Shell scripts

`install.sh`, `update.sh`, and `uninstall.sh` at the repo root are copied into the skill directories on install. They are bundled as-is — no compilation required.

- `install.sh [--project]` — installs **every** skill listed in its `SKILLS` variable (`fortrabbit`, `fortrabbit-api-tokens`) into `.claude/skills/<skill>/`, `.agents/skills/<skill>/`, plus `.github/instructions/` (Copilot, project-only). When adding a new skill directory under `skills/`, add its name to `SKILLS` in `install.sh` and `uninstall.sh`.
- `update.sh` — checks `VERSION` against the published version and re-runs `install.sh` if newer
- `uninstall.sh` — removes all installed skill directories (all names in `SKILLS`) and the Copilot instructions file

## Key Conventions

**Config lookup chain** (in order):

1. `.fortrabbit` file (`app-env-id`, `region`) — committed, no secrets
2. `.env` (`FORTRABBIT_APP_ENV_ID`, `FORTRABBIT_REGION`, `FORTRABBIT_DEPLOY_HOOK_SECRET`)
3. Prompt the user if neither exists

**Project type detection** (file/dependency signals):

- `artisan` file or `laravel/framework` in composer.json → Laravel
- `craftcms/cms` in composer.json → Craft CMS
- `statamic/cms` → Statamic
- `getkirby/cms` → Kirby
- `wp-config.php` → WordPress
- Other `composer.json` → Generic PHP

**SSH host pattern:** `APP_ENV_ID@ssh.REGION.frbit.app`

**Deploy hook URL pattern:** `https://api.fortrabbit.com/webhooks/environments/{app-env-id}/deploy/{secret}`

**Docs URL rewriting:** Fetch `https://docs.fortrabbit.com/` pages as raw markdown by appending `.md` and inserting `/raw/` — e.g. `https://docs.fortrabbit.com/guides/foo/bar` → `https://docs.fortrabbit.com/raw/guides/foo/bar.md`

**Safety rules enforced in all formats:**

- Always print the full command before executing
- Require explicit user confirmation for destructive ops (db push/pull, DROP statements)
- Database access is only via SSH tunnel — no direct remote connections
- Never store passwords in files
- Load `connect.md` automatically on SSH failures

**Update check:** `SKILL.md` silently checks for updates once per 7 days (tracked in `.last-update-check`). The check compares `VERSION` against `https://raw.githubusercontent.com/fortrabbit/agent-skills/main/VERSION`.

## Supported Frameworks

Laravel, Craft CMS, Statamic, Kirby, WordPress, Generic PHP. Every reference file must include a section for each of the six stacks.
