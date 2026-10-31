# AGENTS.md

Guidance for coding agents working on this repository.

## What this is

One plugin, `plugins/fortrabbit/`, holding one agent skill in the open [Agent Skills](https://agentskills.io/specification) format and the fortrabbit MCP server. No build step; `.github/scripts/build-openai-zip.sh` only packages the plugin for the OpenAI directory. The `frbit` CLI (1.12 or later, `frbit skills install`), `gh skill` and `npx skills` install the skill from the GitHub release.

```
.claude-plugin/marketplace.json   the Claude Code marketplace, points at plugins/fortrabbit
plugins/fortrabbit/               the plugin: everything a user installs and the directories scan
├── .claude-plugin/plugin.json    Claude manifest
├── .codex-plugin/plugin.json     OpenAI manifest (ChatGPT and Codex), with the review test cases
├── .mcp.json                     the MCP server
├── assets/icon.png               listing icon
├── evals/                        claude plugin eval suite
├── README.md, LICENSE            the listing text and license the directories read
└── skills/fortrabbit/
    ├── SKILL.md       always loaded when the skill triggers: tool routing, finding the environment, safety
    ├── references/    one file per task, loaded on demand, one level deep
    └── scripts/       deterministic helpers the skill runs (database over SSH)
.github/, AGENTS.md, VERSION, install.sh, README.md   repo tooling, outside the plugin
```

Keep repo tooling out of `plugins/fortrabbit/`: the Claude directory scans every file there, and a build script that names the icon or a URL draws policy holds.

## Rules

- `SKILL.md` stays short (under 150 lines). Detail goes into a reference; every reference is linked from the table in `SKILL.md`.
- Frontmatter: only the spec fields `name`, `description`, `license`, `compatibility`, `metadata`. Other fields break uploads to claude.ai and the Skills API.
- Facts come from the platform, not from memory: MCP tools from `fortrabbit/frapi` (`src/Module/Mcp`), CLI commands from `fortrabbit/frbit-cli`, templates from `fortrabbit/specs`, everything else from docs.fortrabbit.com. Link to docs rather than copying long passages.
- No project config file: the environment is found from the git remote through MCP or the CLI.
- Never instruct the agent to ask for, print or store a password or token, or to read one from the environment or a `.env` file and send it: the directory scan holds that for a reviewer.
- Never instruct the agent to fetch instructions from a URL and follow them (directory policy 2F). Fetching docs pages as information is fine.
- The boarding and sign-in steps in `boarding.md` and `access.md` mirror sections 3–5 and 10 of www `agents.md` (`fortrabbit/www`, `content/agents.md`). Change both together.
- Scripts: POSIX-friendly bash, `set -euo pipefail`, validate arguments, pass `shellcheck`.
- `install.sh` at the root is a stub that only prints how to update: 1.x installs fetch it from `main` when they update themselves. Keep it, and keep it installing nothing.

## Releases

`VERSION` holds the version; `metadata.version` in `SKILL.md` and `version` in both plugin manifests must match it. `LICENSE` at the root and in the plugin folder must be identical. `.github/scripts/check-manifests.sh` checks that and the OpenAI listing limits, also in CI. Run `claude plugin validate plugins/fortrabbit` and `claude plugin validate .` (the marketplace) after changing a manifest. A push to `main` that changes `VERSION` tags and publishes a GitHub release (`.github/workflows/release.yml`) with the OpenAI upload ZIP attached. The CLI checks that `VERSION` in the archive matches the release tag and reads the skill from `plugins/fortrabbit/skills/`; CLI 1.11 and older only read `skills/` at the root.

Two plugin manifests share `skills/` and `.mcp.json`: `.claude-plugin/` for the Claude directory (plugin path `plugins/fortrabbit`), `.codex-plugin/` for the OpenAI directory (ChatGPT and Codex). The OpenAI one also holds the review test cases: when an MCP tool is renamed in frapi, update `tools_triggered` there. `.github/scripts/build-openai-zip.sh` builds the upload from the committed files.

## Testing a change

`plugins/fortrabbit/evals/` holds a `claude plugin eval` suite: one folder per case (`prompt.md`, `graders/`), and `mocks/fortrabbit/` there answers the MCP tools with a fixed test account instead of the real server. `_tools.json` there mirrors the tool names and arguments in frapi `McpToolController`: update it when a tool changes. Run `claude plugin eval plugins/fortrabbit --trust-plugin --no-publish` before a release (about $2, cases with and without the plugin); `--case <name> --runs 1` for one case. Results land in `plugins/fortrabbit/evals/results/`, which git ignores. The cases grant no Bash, so the safety cases check what the agent says and which MCP tools it calls, not shell commands.
