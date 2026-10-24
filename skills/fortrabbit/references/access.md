# Access: MCP, CLI and REST API

Three ways in, each with its own sign-in. None of them needs a credential in the chat.

| Route | For | Sign-in |
|---|---|---|
| MCP server `https://mcp.fortrabbit.com/mcp` | Agents: read, provision, env vars, deployment logs | OAuth in the browser, the client stores it |
| `frbit` CLI | Deploy, restart, deletes, CI, everything MCP lacks | `frbit auth login`, token in the system keychain |
| REST API `https://api.fortrabbit.com/v1` | Own scripts and integrations | `Authorization: Bearer frbit-at-…` |

## MCP

```shell
claude mcp add --transport http fortrabbit https://mcp.fortrabbit.com/mcp
codex mcp add fortrabbit --url https://mcp.fortrabbit.com/mcp
frbit mcp install          # either of the above, picked for the installed agent
```

The first tool call opens the browser: the person signs in and approves. Verify with `get_you`. Disconnect with `claude mcp remove fortrabbit`; revoke the grant itself in the dashboard under "AI agents" (`https://dash.fortrabbit.com/you/ai-agents`).

Clients without OAuth can send a Public API token as `Authorization: Bearer` header instead. Keep the config file out of git and prefer `${FORTRABBIT_API_TOKEN}` interpolation over the literal value.

## CLI

```shell
brew install fortrabbit/tap/frbit      # or: npm install --global @fortrabbit/cli
frbit auth login                       # opens the token page, stores the token in the keychain
frbit auth status
```

Groups: `apps`, `environments`, `deployments`, `domains`, `teams`, `people`, `payment-methods`, `auth`, `mcp`, `skills`, `setup`. Run `frbit <group> --help` rather than guessing a subcommand. `--json` on list, get, create, update, deploy and logs prints the API response.

Every environment command takes the environment ID; there is no default environment. In CI, set `FRBIT_TOKEN` instead of logging in.

## REST API

```shell
curl https://api.fortrabbit.com/v1/apps \
  -H "Authorization: Bearer ${FORTRABBIT_API_TOKEN}" -H "Accept: application/json"
```

- `GET /v1/docs` is public and the source of truth for endpoints and payloads.
- `/apps`, `/environments` and `/domains` are paginated, 30 per page.
- Rate limit about 20 requests per minute per token, shared with MCP. A `429` carries `Retry-After`.

## Public API tokens

`frbit-at-` plus 64 hex characters. It acts as the person on all their apps: treat it as a password.

1. Check whether one exists without printing it: `[ -n "${FORTRABBIT_API_TOKEN:-}" ] && echo set`, then `grep -q '^FORTRABBIT_API_TOKEN=' .env && echo set` in a git-ignored `.env`. Pass it on as `${FORTRABBIT_API_TOKEN}`, never as a literal.
2. None found: the person creates one at `https://dash.fortrabbit.com/new/api-token` (shown once) and stores it themselves, in the environment or a git-ignored `.env`. Check `.gitignore` before suggesting `.env`.
3. Never print a token in full: show `frbit-at-…` plus the last four characters. List and revoke tokens at `https://dash.fortrabbit.com/you/api-tokens`.

## Errors

| Symptom | Meaning | Fix |
|---|---|---|
| `401` on `/mcp` | Not signed in, or the grant expired or was revoked | Let the client re-run OAuth; else remove and re-add the server |
| `401` on `/v1` | Missing header, wrong scheme or invalid token | Send `Authorization: Bearer <token>` exactly |
| `403` / `Access denied.` | Signed in, but the object is not this account's | Check `get_you`; client accounts cannot create environments |
| `Account blocked.`, unverified, not onboarded | The account itself is not usable yet | The person fixes it in the dashboard |
| `429` | Rate limit | Wait for `Retry-After`; never retry a failed sign-in in a loop |
