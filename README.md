# fortrabbit agent skills

The fortrabbit plugin for coding agents: a skill that teaches an agent to deploy, operate and debug PHP apps on [fortrabbit](https://www.fortrabbit.com), plus the fortrabbit MCP server. It works in Claude Code, claude.ai, Cowork, OpenAI Codex, GitHub Copilot, Cursor and other agents that read `SKILL.md`.

The plugin lives in [`plugins/fortrabbit/`](plugins/fortrabbit/). Its [README](plugins/fortrabbit/README.md) covers installing, what the plugin connects to, and privacy.

Quick install:

```shell
/plugin marketplace add fortrabbit/agent-skills    # Claude Code
/plugin install fortrabbit@fortrabbit
frbit skills install                               # any agent, with the fortrabbit CLI 1.12 or later
```

Docs: [agent skills on docs.fortrabbit.com](https://docs.fortrabbit.com/platform/automation/agent-skills). Contributing: [AGENTS.md](AGENTS.md).
