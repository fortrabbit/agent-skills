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

Version 2 merges `fortrabbit-api-access` into `fortrabbit` and drops the install scripts. `frbit skills update` removes the old skill folder and the old Copilot instructions file. After a `gh skill` or manual install, delete them yourself:

```shell
rm -rf ~/.claude/skills/fortrabbit-api-access ~/.agents/skills/fortrabbit-api-access
rm -f .github/instructions/fortrabbit.instructions.md
```

A `.fortrabbit` file with `app-env-id=` in your project is no longer read: the skill finds the environment from the git remote. Delete it.

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

## Privacy

The skill runs locally in your agent. The plugin connects your agent to the fortrabbit MCP server; see the [privacy statement](https://www.fortrabbit.com/legal/data-protection/privacy-statement).

## License

MIT
