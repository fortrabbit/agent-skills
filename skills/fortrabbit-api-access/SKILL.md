---
name: fortrabbit-api-access
description: >
  Use when connecting an agent, MCP client, or script to fortrabbit — installing
  the fortrabbit MCP server (`api.fortrabbit.com/mcp`), calling the `/v1` REST
  API, or resolving `401` / "Authentication required" / "Invalid access token"
  errors. Prefers the browser-based OAuth install (no credential handling) and
  falls back to a dashboard-issued `frbit-at-` Public API token for REST, CI, and
  clients without OAuth support. Trigger on mentions of "connect fortrabbit",
  "install the fortrabbit MCP server", "fortrabbit token", "API token",
  "frbit-at-", "Bearer", "MCP", "/v1", or "dash.fortrabbit.com".
compatibility: >
  Requires network access to https://api.fortrabbit.com (serves `/mcp`, `/v1`,
  and the OAuth endpoints) and to https://dash.fortrabbit.com for token
  creation. OAuth install requires an MCP client that supports Client ID
  Metadata Documents (Claude Code, Codex) and a browser on the user's machine.
  `curl` is used for REST examples. Designed for Claude Code; works with any
  agent that reads SKILL.md.
license: MIT
metadata:
  version: "0.4.0"
  author: fortrabbit
user-invocable: true
allowed-tools: Bash Read Glob Grep
argument-hint: "[install | find | store | mcp | api | generate | help]"
---

You connect an agent to fortrabbit so it can use the **MCP server** (`/mcp`) or
the **Public API** (`/v1`) on the user's behalf.

There are two ways in. Pick by what the user is connecting:

| Situation | Path |
|-----------|------|
| An MCP client (Claude Code, Codex, Cursor) needs the fortrabbit MCP server | **OAuth install** — Step 1. No token, no secret handling. |
| A script, CI job, or `curl` needs the `/v1` REST API | **Public API token** — Step 3. |
| An MCP client with no OAuth support | **Public API token** — Step 3, configured as a Bearer header. |

Default to OAuth. Only reach for a token when OAuth cannot apply.

---

## Step 1 — Install the MCP server via OAuth (preferred)

One command. The client opens a browser, the user approves, and the client
stores the credentials itself. **The agent never sees, handles, or stores a
token in this flow.**

**Claude Code:**

```sh
claude mcp add --transport http fortrabbit https://api.fortrabbit.com/mcp
```

**OpenAI Codex** — Codex does not publish a Client ID Metadata Document, so it
must be given the client ID explicitly:

```sh
codex mcp add fortrabbit --url https://api.fortrabbit.com/mcp --oauth-client-id https://api.fortrabbit.com/.well-known/oauth-client/codex
```

After running it, tell the user to complete the browser approval, then verify by
calling the `get_you` tool — it returns the account the connection authenticates
as.

What happens under the hood (useful for diagnosing, not for reimplementing):

- The first unauthenticated request gets a `401` carrying
  `WWW-Authenticate: Bearer resource_metadata="https://api.fortrabbit.com/.well-known/oauth-protected-resource/mcp"`.
  The client follows that to the discovery documents and starts the flow.
- Authorization code + PKCE (`S256`), no client secret, single `mcp` scope.
- The server issues a short-lived opaque `frbit-mcp-at-` access token (1 hour)
  and a rotating `frbit-mcp-rt-` refresh token. The client refreshes silently.
- **There is no dynamic client registration.** Clients identify themselves with
  a Client ID Metadata Document. Do not look for or configure a
  `registration_endpoint` — its absence is deliberate.

**Never try to mint, read, or hand-edit `frbit-mcp-at-` / `frbit-mcp-rt-`
tokens.** They are opaque, short-lived, and managed by the client. If auth
breaks, re-run the install command rather than manufacturing a credential.

To disconnect, remove the server in the client (e.g. `claude mcp remove
fortrabbit`). That drops the credentials the client stored, but does **not**
revoke the grant server-side. Server-side revocation
(`DELETE /you/connected-apps/{publicId}`) is session-authenticated — it needs a
logged-in browser session and is not reachable with an API token, so neither an
agent nor `curl` can perform it. Direct the user to do it in the dashboard.

---

## Step 2 — Confirm the connection works

```
Call get_you
```

It returns `publicId`, `email`, `name`, `type`, `active`, `client`,
`gitAccountConnected`, `gitUsername`, `gitInstallationAccounts`. Two fields
matter before doing anything else:

- `client: true` → this is a client account; it **cannot create environments**.
- `gitAccountConnected: false` → no git-based deployment is possible until the
  user connects a git account in the dashboard.

**MCP calls are rate limited too**, on the same budget as the REST API: roughly
20 requests per minute, keyed per token — an OAuth token and a `frbit-at-` token
are limited identically. Each tool call is one request, so a burst of discovery
calls can hit `429`. Space out exploratory calls rather than enumerating every
list tool at once.

For what to do with the connection once it works, see `references/mcp.md` in the
`fortrabbit` skill — it documents the full tool catalogue and workflow.

---

## Step 3 — Public API token (REST, CI, and non-OAuth clients)

A **Public API token** is a long-lived dashboard-issued credential:

- **Format:** `frbit-at-` followed by 64 hex characters, e.g.
  `frbit-at-6a7747a7…db1744` (never reproduce a full token, here or anywhere).
- **Where it works:** authenticates both `/v1` and `/mcp`, sent as
  `Authorization: Bearer frbit-at-…`. On `/mcp` it is accepted for compatibility
  alongside OAuth.
- **Created only in the dashboard.** Minted through the session-authenticated
  web app, shown **once**, never retrievable again — fortrabbit stores only a
  SHA-256 hash plus the last 4 characters.

> **A token acts as the user.** It authenticates every request as the `Person`
> who owns it and is tenant-scoped to their apps. Treat it like a password:
> never print it in full, never commit it, never paste it into a chat log,
> skill, or source file.

### 3a — Find an existing token before asking

Run these in order and stop at the first hit:

```sh
# 1. Environment variable (preferred store)
printenv FORTRABBIT_API_TOKEN

# 2. .env file in the project root
grep -E '^(FORTRABBIT_API_TOKEN|FORTRABBIT_TOKEN)=' .env 2>/dev/null

# 3. Any frbit-at- value, even under a differently named variable
grep -rhoE 'frbit-at-[0-9a-f]{64}' .env .env.local 2>/dev/null | head -n1
```

If a value is found, use it — do **not** ask the user again. When echoing it
back, **mask it**: show only `frbit-at-…` plus the last 4 characters (e.g.
`frbit-at-…1744`). Never print the full value.

### 3b — Store it safely

- **Preferred:** an environment variable `FORTRABBIT_API_TOKEN`, or a line in a
  git-ignored `.env`:
  ```sh
  echo 'FORTRABBIT_API_TOKEN=frbit-at-…' >> .env
  ```
- **Confirm `.env` is git-ignored** before writing to it:
  ```sh
  grep -qxF '.env' .gitignore || echo "WARNING: .env is not git-ignored — do not write the token there."
  ```

Never write the token into `.fortrabbit` (that file is committed and holds no
secrets), into `SKILL.md`, or into any file that gets committed or logged.

### 3c — Generate one when none exists

The agent cannot create the first token — it is a chicken-and-egg, so walk the
user through it:

1. Open **https://dash.fortrabbit.com/new/api-token**.
2. Give it a descriptive **name** (required) — e.g. the machine or agent that
   will use it.
3. **Copy it immediately** — shown once, never retrievable. If lost, delete it
   and create a new one.
4. Ask the user to paste it privately (not into a shared or logged channel),
   then store it per Step 3b and confirm back only the masked preview.

Existing tokens are listed and revoked at
**https://dash.fortrabbit.com/you/api-tokens**. Revocation is immediate.

---

## Step 4 — Use the token with the REST API (`/v1`)

The scheme is literally `Bearer` — a bare token, `Authorization: Token …`, or a
query parameter will not authenticate.

```sh
curl https://api.fortrabbit.com/v1/apps \
  -H "Authorization: Bearer ${FORTRABBIT_API_TOKEN}" \
  -H "Accept: application/json"
```

Conventions worth knowing before writing a client:

- **Docs:** `GET /v1/docs` is public (no token) and is the source of truth for
  endpoints and payloads. Point the user there to discover resources.
- **Pagination:** `GET /apps`, `GET /environments`, and `GET /domains` are
  paginated at a fixed 30 items per page. `GET /teams`,
  `GET /payment-methods`, and deployment collections are not paginated.
- **Filtering by ID:** repeat the `publicId[]` parameter, e.g.
  `?publicId[]=do-abc123&publicId[]=do-def456`. A single ID may also be passed
  as a scalar, `?publicId=do-abc123`. Each ID must match
  `^[a-z]{2}-[0-9a-z]{6}$` with that collection's prefix; max 30, no duplicates.
  Violations return **422**. A well-formed but unknown ID is silently absent
  from a **200** response.
- **Rate limit:** roughly 20 requests per minute per token, shared with `/mcp`.
  Responses carry `X-RateLimit-Limit` and `X-RateLimit-Remaining`; a `429` adds
  `X-RateLimit-Reset` and `Retry-After`. Failed authentications are counted
  separately per IP, so do not retry a bad credential in a loop.

### Using a token with an MCP client (fallback)

Only when the client cannot do OAuth. Configure the `/mcp` endpoint with the
Bearer header — keep the file out of version control if it embeds the value:

```json
{
  "mcpServers": {
    "fortrabbit": {
      "type": "http",
      "url": "https://api.fortrabbit.com/mcp",
      "headers": {
        "Authorization": "Bearer frbit-at-…"
      }
    }
  }
}
```

Prefer `${FORTRABBIT_API_TOKEN}` interpolation if the client supports it, rather
than pasting the literal value.

---

## Quick reference

| Need | Do this |
|------|---------|
| Connect an MCP client | `claude mcp add --transport http fortrabbit https://api.fortrabbit.com/mcp` |
| Connect Codex | add `--oauth-client-id https://api.fortrabbit.com/.well-known/oauth-client/codex` |
| Verify a connection | Call `get_you` |
| Find a token | `printenv FORTRABBIT_API_TOKEN`, then grep `.env` for `frbit-at-[0-9a-f]{64}` |
| Store a token | `FORTRABBIT_API_TOKEN` env var or git-ignored `.env` line |
| MCP endpoint | `https://api.fortrabbit.com/mcp` |
| REST endpoint | `https://api.fortrabbit.com/v1/…`, header `Authorization: Bearer frbit-at-…` |
| Discover REST resources | `GET /v1/docs` (public, no token) |
| Generate a token | https://dash.fortrabbit.com/new/api-token |
| List / revoke tokens | https://dash.fortrabbit.com/you/api-tokens |
| Mask for display | `frbit-at-…{last4}` — never the full value |

---

## Common errors

| Symptom | Meaning | Fix |
|---------|---------|-----|
| `401` on `/mcp`, body `Full authentication is required to access this resource.`, header `WWW-Authenticate: Bearer resource_metadata=…` | The **only** 401 `/mcp` returns — missing, malformed, unknown, expired, revoked, and wrong-audience credentials are deliberately indistinguishable | Let the client re-run its OAuth flow; if it cannot, re-run the install command from Step 1, or re-copy the full `frbit-at-…` value |
| `401` on `/v1` | Missing `Authorization` header, wrong scheme, or an invalid token — the response does not say which | Send `Authorization: Bearer <token>` exactly — not `Token`, not a query param — then re-copy the token if the header was already right |
| `403` / `Sorry. Access denied.` on `/mcp` | Authenticated, but the resource isn't the token owner's | Confirm the resource belongs to the account — check `get_you` |
| `403` on `/v1` | Same cause; the message wording differs from `/mcp` | Confirm the resource belongs to the account — check `get_you` |
| `403` / `Account blocked.` / `unverified` / `unonboarded` | The account itself is not usable | The user must resolve it in the dashboard |
| `429` | Rate limit (~20/min per token, shared across `/v1` and `/mcp`) | Back off and retry after `Retry-After`. Never retry a failed auth in a loop — failures are rate-limited per IP |
| `unsupported_grant_type` from `/oauth2/token` | A client tried a grant other than `authorization_code` / `refresh_token` | Only those two are supported; there is no client-credentials flow |

---

## Safety rules

- Never print, log, echo, or commit the full token. Display only the masked
  `frbit-at-…{last4}` preview.
- Never store a token in a committed file (`.fortrabbit`, source, `SKILL.md`).
  Use an env var or a git-ignored `.env`.
- Never hand-manage `frbit-mcp-at-` / `frbit-mcp-rt-` OAuth tokens — the client
  owns them.
- Prefer env interpolation (`${FORTRABBIT_API_TOKEN}`) over pasting a literal
  value into commands or MCP config.
- A Public API token acts as the user across all their apps — treat it as a full
  credential, not a scoped read key.
- If a token may have leaked, tell the user to delete it at
  https://dash.fortrabbit.com/you/api-tokens (revocation is immediate) and
  generate a replacement.

---

## Response format

```
I'll [one-sentence description of what you're about to do].

[exact command(s) — with any token shown only as ${FORTRABBIT_API_TOKEN} or masked]

Result: [outcome, token masked as frbit-at-…{last4}]

Next step: [one concrete follow-up, e.g. "Call get_you to confirm which account you're connected as"]
```
