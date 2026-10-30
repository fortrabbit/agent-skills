# Access: MCP, CLI and REST API

Three ways in, each with its own sign-in. None of them needs a credential in the chat.

| Route | For | Sign-in |
|---|---|---|
| MCP server `https://mcp.fortrabbit.com/mcp` | Agents: read, provision, env vars, deployment logs | OAuth in the browser, the client stores it |
| `frbit` CLI | Deploy, restart, deletes, CI, everything MCP lacks | `frbit auth login` (`--signup` when the person has no account), token in the system keychain |
| REST API `https://api.fortrabbit.com/v1` | Own scripts and integrations | `Authorization: Bearer frbit-at-…` |

## MCP

```shell
claude mcp add --transport http fortrabbit https://mcp.fortrabbit.com/mcp
codex mcp add fortrabbit --url https://mcp.fortrabbit.com/mcp
frbit mcp install          # either of the above, picked for the installed agent
```

The first tool call opens the browser: the person signs in and approves. Verify with `get_you`. Disconnect with `claude mcp remove fortrabbit`; revoke the grant itself in the dashboard under "AI agents" (`https://dash.fortrabbit.com/you/ai-agents`).

## CLI

```shell
curl -fsSL https://www.fortrabbit.com/agents.sh | sh   # installs frbit, then runs frbit setup agent
brew install fortrabbit/tap/frbit      # or: npm install --global @fortrabbit/cli
frbit auth login --json                # browser sign-in
frbit auth login --signup --json       # the person said they have no account
frbit auth status --json
```

### Sign in from an agent

Account state decides the command. Account unknown or existing: `frbit auth login --json` (the login page offers sign-up too). Only when the person said they have no account: `frbit auth login --signup --json`. Add `--name "<name>"` only with a name the person gave in the chat or that `git config user.name` returns; never invent a name and never pass the e-mail address.

Shell tools often time out after about two minutes, and the person has up to 15 minutes. Run `frbit auth login --json` in the background (or with a long timeout):

1. It prints `{"url": …, "confirmation_code": …, "status": "waiting"}` at once. Show the person the URL and the code: they open the URL and type the code on the consent page. It is their step; never type the code yourself. `--no-browser` only prints the URL, for a machine without a browser.
2. Poll `frbit auth status --json` until it reports `"status": "signed_in"`. `"status": "signed_out"` while the login runs means the person has not finished: keep waiting and do not start a second login. `"status": "error"` while the login runs (an old credential was revoked or expired, say) counts the same: keep waiting and read the login's own last JSON line. The login itself ends with `{"status": "signed_in", "next": …}`, or `{"status": "error", "code": …, "error": …}`: read `next` straight from that line. `code` is set for stable failures. On `"code": "access_denied"` the person denied the consent request, and that request is used up: ask the person whether to try again, and run `frbit auth login --json` again only after they say yes. Never retry on your own. `"code": "timeout"`: the 15 minutes ran out, ask before starting again. `"code": "frbit_token_set"`: `FRBIT_TOKEN` is set in the shell and overrides any login; the person unsets it or keeps using it.
3. Follow `next`, an object `{step, instruction, url}`, one step at a time:
   - `connect_git`: [git-github.md](git-github.md).
   - `add_payment_method`: show the person `next.instruction` and `next.url`. It is their step in the browser; never take card or payment details in the chat. Wait, then re-check status.
   - `ready`: carry on.
   After each step run `frbit auth status --json` again. Repeat until `step` is `ready`.

If `frbit` fails with "unknown flag", the installed CLI is too old (`frbit deployments list --environment` needs 1.11.0): upgrade it with `brew upgrade fortrabbit/tap/frbit` or `npm install --global @fortrabbit/cli@latest`, then start again.

Never ask for a password or token in the chat. Pasting a token (`--token-stdin`) is for CI.

Groups: `apps`, `environments`, `deployments`, `domains`, `teams`, `people`, `payment-methods`, `auth`, `mcp`, `skills`, `setup`. Run `frbit <group> --help` rather than guessing a subcommand. `--json` on list, get, create, update, deploy and logs prints the API response.

Every environment command takes the environment ID; there is no default environment. In CI, set `FRBIT_TOKEN` (or pipe a token to `--token-stdin`) instead of logging in.

`frbit environments variables get --json` masks the values; `--reveal` shows them. Reveal only a variable the person asked about, and never paste secrets into the chat.

Remove everything fortrabbit set up on the machine (MCP server, skill, plugin, CLI sign-in, the CLI itself): `frbit uninstall`. Only the agent setup, keeping the CLI: `frbit setup agent --remove`. Both list what they remove and ask first.

## REST API

For scripts and integrations the person builds. The agent works through MCP or the CLI, which sign in on their own and cover the same endpoints: `frbit <group> … --json` prints the API response.

- `GET https://api.fortrabbit.com/v1/docs` is public and the source of truth for endpoints and payloads.
- `/apps`, `/environments`, `/domains` and `/deployments` are paginated, 30 per page. `/deployments` is newest first and takes `?environment=en-…`.
- Rate limit about 20 requests per minute per token, shared with MCP. A `429` carries `Retry-After`.

## Public API tokens

`frbit-at-` plus 64 hex characters. It acts as the person on all their apps: treat it as a password. The person creates it at `https://dash.fortrabbit.com/new/api-token` (shown once) and puts it into their CI secret or script themselves; the agent does not look for, read or send it. List and revoke tokens at `https://dash.fortrabbit.com/you/api-tokens`.

A token carries scopes: `read` (GET), `write` (also POST, PUT, PATCH), `delete` (also DELETE). A CI job that deploys or restarts needs `write`.

## Errors

| Symptom | Meaning | Fix |
|---|---|---|
| `401` on `/mcp` | Not signed in, or the grant expired or was revoked | Let the client re-run OAuth; else remove and re-add the server |
| `401` on `/v1` | Missing header, wrong scheme or invalid token | Send `Authorization: Bearer <token>` exactly |
| `403` / `Access denied.` | Signed in, but the object is not this account's | Check `get_you`; client accounts cannot create environments |
| `403` on `/v1` or from `frbit` with `FRBIT_TOKEN` | The token lacks the scope for this method | The person creates a token with `write` or `delete` |
| `Account blocked.`, unverified, not onboarded | The account itself is not usable yet | The person fixes it in the dashboard |
| `429` | Rate limit | Wait for `Retry-After`; never retry a failed sign-in in a loop |
