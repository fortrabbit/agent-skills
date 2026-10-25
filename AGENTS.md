# AGENTS.md

Guidance for coding agents working on this repository.

## What this is

One agent skill, `skills/fortrabbit/`, in the open [Agent Skills](https://agentskills.io/specification) format. No build step. The `frbit` CLI (`frbit skills install`), `gh skill` and `npx skills` install it from the GitHub release.

```
skills/fortrabbit/
├── SKILL.md       always loaded when the skill triggers: tool routing, finding the environment, safety
├── references/    one file per task, loaded on demand, one level deep
└── scripts/       deterministic helpers the skill runs (database over SSH)
```

## Rules

- `SKILL.md` stays short (under 150 lines). Detail goes into a reference; every reference is linked from the table in `SKILL.md`.
- Frontmatter: only the spec fields `name`, `description`, `license`, `compatibility`, `metadata`. Other fields break uploads to claude.ai and the Skills API.
- Facts come from the platform, not from memory: MCP tools from `fortrabbit/frapi` (`src/Module/Mcp`), CLI commands from `fortrabbit/frbit-cli`, templates from `fortrabbit/specs`, everything else from docs.fortrabbit.com. Link to docs rather than copying long passages.
- No project config file: the environment is found from the git remote through MCP or the CLI.
- Never instruct the agent to ask for, print or store a password or token.
- Scripts: POSIX-friendly bash, `set -euo pipefail`, validate arguments, pass `shellcheck`.
- `install.sh` at the root is a stub that only prints how to update: 1.x installs fetch it from `main` when they update themselves. Keep it, and keep it installing nothing.

## Releases

`VERSION` holds the version, and `metadata.version` in `SKILL.md` must match it. A push to `main` that changes `VERSION` tags and publishes a GitHub release (`.github/workflows/release.yml`). The CLI checks that `VERSION` in the archive matches the release tag.

## Testing a change

No test suite. Before a release, run the scenarios from the PR description against the changed skill in a dry run (the agent lists the tool calls and commands it would run, nothing is executed) and compare with the previous version.
