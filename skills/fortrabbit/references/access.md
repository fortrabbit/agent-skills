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

The first tool call opens the browser: the person signs in and approves. Verify with `get_you`. Disconnect with `claude mcp remove fortrabbit`; revoke the grant itself in the dashboard under "Connections" (`https://dash.fortrabbit.com/you/ai-agents`).

Clients without OAuth can send a Public API token as `Authorization: Bearer` header instead. Keep the config file out of git and prefer `${FORTRABBIT_API_TOKEN}` interpolation over the literal value.

## CLI

```shell
brew install fortrabbit/tap/frbit      # or: npm install --global @fortrabbit/cli
frbit auth login --json                # browser sign-in
frbit auth login --signup --json       # the person said they have no account
frbit auth status --json
```

### Sign in from an agent

Account state decides the command. Account unknown or existing: `frbit auth login --json` (the login page offers sign-up too). Only when the person said they have no account: `frbit auth login --signup --json`. Add `--name "<name>"` only with a name the person gave in the chat or that `git config user.name` returns; never invent a name and never pass the e-mail address.

Shell tools often time out after about two minutes, and the person has up to 15 minutes. Run `frbit auth login --json` in the background (or with a long timeout):

1. It prints `{"url": …, "confirmation_code": …, "status": "waiting"}` at once. Show the person the URL and the code: they open the URL and type the code on the consent page. It is their step; never type the code yourself. `--no-browser` only prints the URL, for a machine without a browser.
2. Poll `frbit auth status --json` until it reports `"status": "signed_in"`. `"status": "signed_out"` while the login runs means the person has not finished: keep waiting and do not start a second login. `"status": "error"` while the login runs (an old credential was revoked or expired, say) counts the same: keep waiting and read the login's own last JSON line. The login itself ends with `{"status": "signed_in", "next": …}`, or `{"status": "error", "code": …, "error": …}`: read `next` straight from that line. `code` is set for stable failures. On `"code": "access_denied"` the person denied the consent request, and that request is used up: ask the person whether to try again, and run `frbit auth login --json` again only after they say yes. Never retry on your own.
3. Follow `next`, an object `{step, instruction, url}`, one step at a time:
   - `connect_git`: [git-github.md](git-github.md).
   - `add_payment_method`: show the person `next.instruction` and `next.url`. It is their step in the browser; never take card or payment details in the chat. Wait, then re-check status.
   - `ready`: carry on.
   After each step run `frbit auth status --json` again. Repeat until `step` is `ready`.

If `frbit` fails with "unknown flag: --json", the installed CLI is too old: upgrade it with `brew upgrade fortrabbit/tap/frbit` or `npm install --global @fortrabbit/cli@latest`, then start again.

Never ask for a password or token in the chat. Pasting a token (`--token-stdin`) is for CI.

Groups: `apps`, `environments`, `deployments`, `domains`, `teams`, `people`, `payment-methods`, `auth`, `mcp`, `skills`, `setup`. Run `frbit <group> --help` rather than guessing a subcommand. `--json` on list, get, create, update, deploy and logs prints the API response.

Every environment command takes the environment ID; there is no default environment. In CI, set `FRBIT_TOKEN` (or pipe a token to `--token-stdin`) instead of logging in.

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
