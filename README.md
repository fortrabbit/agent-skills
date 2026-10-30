# fortrabbit agent skills

Teaches a coding agent how to work with [fortrabbit](https://www.fortrabbit.com), the managed PHP hosting platform: find the environment of the current repo, deploy, read deployment logs, change environment variables, run remote commands, pull and push the database, sync files and debug HTTP errors. Works with Laravel, Craft CMS, Statamic, Kirby, WordPress, Symfony and plain PHP.

The skill is written in the open [Agent Skills](https://agentskills.io) format and works in Claude Code, OpenAI Codex, GitHub Copilot, Cursor and other agents that read `SKILL.md`.

## Install

Claude Code, as a plugin with the skill and the MCP server in one go:

```shell
/plugin marketplace add fortrabbit/agent-skills
/plugin install fortrabbit@fortrabbit
```

On Claude Code 2.1.275 or later in one step: `/plugin install fortrabbit --marketplace fortrabbit/agent-skills`. If you already added the MCP server with `claude mcp add`, remove that one (`claude mcp remove fortrabbit`) so the tools are not listed twice. Updates arrive with `/plugin marketplace update fortrabbit`.

Any agent, with the fortrabbit CLI, which also connects the MCP server:

```shell
frbit setup agent           # skills + MCP server
frbit skills install        # skills only; --agent claude-code|codex|copilot, --project
frbit skills update
```

With the GitHub CLI (v2.90+) or `npx skills`:

```shell
gh skill install fortrabbit/agent-skills fortrabbit --agent claude-code --scope user
npx skills add fortrabbit/agent-skills
```

Update with `frbit skills update`, `gh skill update` or `npx skills update`.

### Upgrading from 1.x

Version 2 merges `fortrabbit-api-access` into `fortrabbit` and drops the install scripts. `frbit skills update` (CLI 1.7.0 or later) removes the old skill folder and the old Copilot instructions file. After a `gh skill` or manual install, delete them yourself:

```shell
rm -rf ~/.claude/skills/fortrabbit-api-access ~/.agents/skills/fortrabbit-api-access
rm -f .github/instructions/fortrabbit.instructions.md
```

A `.fortrabbit` file with `app-env-id=` in your project is no longer read: the skill finds the environment from the git remote. Delete it. A `.fortrabbit/` folder is different: it holds the deploy file `.fortrabbit/deploy.yml`.

## Connect fortrabbit

The skill works best with the fortrabbit MCP server and the `frbit` CLI. Both sign in through the browser; no token passes through the chat.

```shell
claude mcp add --transport http fortrabbit https://mcp.fortrabbit.com/mcp
codex mcp add fortrabbit --url https://mcp.fortrabbit.com/mcp
brew install fortrabbit/tap/frbit && frbit auth login
```

## What's inside

```
.claude-plugin/        Claude Code plugin and marketplace manifests
.mcp.json              the fortrabbit MCP server, for the plugin
skills/fortrabbit/
├── SKILL.md            which tool for what, finding the environment, safety rules
├── references/         one file per task, loaded on demand
└── scripts/            database pull and push over SSH
```

## Requirements

`git` and `ssh` (port 22). `rsync` for file sync, a MySQL client for database work. On Windows, rsync needs WSL.

## Docs

- [Agent skills](https://docs.fortrabbit.com/platform/automation/agent-skills)
- [MCP server](https://docs.fortrabbit.com/platform/automation/mcp), [CLI](https://docs.fortrabbit.com/platform/automation/cli), [API](https://docs.fortrabbit.com/platform/automation/api)

## What the plugin connects to

The skill is Markdown instructions plus two shell scripts. Nothing runs in the background: every connection below is a tool call or command the agent runs in the session, visible in the transcript. The agent asks before anything that changes state.

| Destination | Purpose | When |
| -- | -- | -- |
| `https://mcp.fortrabbit.com/mcp` | The MCP server from `.mcp.json`. Reads apps, environments, deployments, domains, teams and payment methods. Creates apps and environments, updates environments | fortrabbit tool calls, after you sign in through the browser |
| `https://docs.fortrabbit.com` | Docs pages as Markdown | Questions the skill doesn't cover |
| `https://api.fortrabbit.com/v1` | The public API, through the `frbit` CLI or with a token you create | CLI commands and API calls |
| `<env>@ssh.<region>.frbit.app` | Remote commands, `rsync`, and the database scripts in `scripts/` | Remote commands, file sync, database pull and push |
| Your site's domains (`*.frbit.app`, `*.frbit.cloud`, custom domains) | Requests to your site, to read status codes and headers | Debugging an HTTP error |
| `https://fortrabbit.betteruptime.com` | Platform status | Debugging an outage |
| GitHub | `gh repo create`, the fortrabbit GitHub App | Creating a repository for a new app |

The agent asks before it installs the `frbit` CLI (Homebrew or npm) or creates an SSH key.

The MCP server and the CLI sign in through the browser, and the CLI keeps its credential in the operating system's credential store. The skill never asks for a password or token in the chat, and never reads one from your environment or `.env` files. The database scripts run `mysqldump` and `mysql` on the environment, so the database password never leaves it. Dumps land in the system temp folder.

## Privacy

The plugin collects no usage data and sends no telemetry. Requests to fortrabbit fall under the [privacy statement](https://www.fortrabbit.com/legal/data-protection/privacy-statement). Disconnect an agent under "AI agents" in the dashboard: `https://dash.fortrabbit.com/you/ai-agents`.

## License

MIT
