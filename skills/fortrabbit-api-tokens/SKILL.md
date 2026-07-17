---
name: fortrabbit-api-tokens
description: >
  Use when connecting an agent, MCP client, or script to the fortrabbit Public
  API or MCP server and a Bearer token is needed — calling the `/v1` REST API,
  wiring up the `/mcp` endpoint, or resolving `401 Invalid API token` /
  "Authentication required" errors. Covers finding an existing `frbit-at-` token
  in the environment, storing it safely, and guiding the user to generate one in
  the dashboard when none exists. Trigger on mentions of "fortrabbit token",
  "API token", "frbit-at-", "Bearer", "MCP", "/v1", or "dash.fortrabbit.com".
compatibility: >
  Requires network access to the fortrabbit Public API host (serves `/v1` and
  `/mcp`) and to https://dash.fortrabbit.com for token creation. `curl` is used
  for REST examples. MCP usage requires an MCP-capable client (e.g. Claude Code).
  Designed for Claude Code; works with any agent that reads SKILL.md.
license: MIT
metadata:
  version: "0.3.0"
  author: fortrabbit
user-invocable: true
allowed-tools: Bash Read Glob Grep
argument-hint: "[find | store | mcp | api | generate | help]"
---

You help an agent obtain, store, and use a fortrabbit **Public API token** so it
can call the REST API (`/v1`) or the MCP server (`/mcp`) on the user's behalf.

> **A token acts as the user.** It authenticates every request as the `Person`
> who owns it and is tenant-scoped to their apps. Treat it like a password:
> never print it in full, never commit it, never paste it into a chat log,
> skill, or source file.

---

## What a fortrabbit API token is

- **Format:** `frbit-at-` followed by 64 hex characters, e.g.
  `frbit-at-6a7747a72ca483b53eb2723b53a43ccd6e03ce37127955f290738cbd62db1744`.
- **Where it works:** the same token authenticates both the `/v1` REST API and
  the `/mcp` MCP endpoint, sent as `Authorization: Bearer frbit-at-…`.
- **Created only in the dashboard.** The token is minted through the
  session-authenticated web app, shown **once**, and cannot be retrieved again —
  fortrabbit stores only a SHA-256 hash plus the last 4 characters. There is no
  API call to create the first token (it would be a chicken-and-egg).

---

## Step 1 — Find an existing token before asking the user

Always check the environment before asking the user for a token. Run these in
order and stop at the first hit:

```sh
# 1. Environment variable (preferred store)
printenv FORTRABBIT_API_TOKEN

# 2. .env file in the project root
grep -E '^(FORTRABBIT_API_TOKEN|FORTRABBIT_TOKEN)=' .env 2>/dev/null

# 3. Any frbit-at- value, even under a differently named variable
grep -rhoE 'frbit-at-[0-9a-f]{64}' .env .env.local 2>/dev/null | head -n1
```

If a value is found, use it — do **not** ask the user again. If nothing is
found, go to Step 4 (generate one).

When echoing what you found back to the user, **mask it**: show only
`frbit-at-…` plus the last 4 characters (e.g. `frbit-at-…1744`) — the same
masked preview the dashboard shows. Never print the full value.

---

## Step 2 — Store the token safely

Store it once so the agent and CLI/MCP client can reuse it without re-prompting:

- **Preferred:** an environment variable named `FORTRABBIT_API_TOKEN`, or a
  line in `.env` (which must be git-ignored):
  ```sh
  echo 'FORTRABBIT_API_TOKEN=frbit-at-…' >> .env
  ```
- **Confirm `.env` is git-ignored** before writing to it:
  ```sh
  grep -qxF '.env' .gitignore || echo "WARNING: .env is not git-ignored — do not write the token there."
  ```
- **For an MCP client**, store it as the server's secret/header (see Step 3), not
  in committed config.

Never write the token into `.fortrabbit` (that file is committed and holds no
secrets), into `SKILL.md`, or into any file that gets committed or logged.

---

## Step 3 — Use the token with the MCP server (`/mcp`)

The MCP server exposes tenant-scoped reads (apps, environments, deployments,
domains, teams, payment methods) plus `create_app` and `create_environment`.
Configure the client to reach the `/mcp` endpoint with the Bearer token as a
header. Example for a Claude Code / generic `mcpServers` config
(`.mcp.json` — keep it out of version control if it embeds the token):

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

Prefer referencing the token via `${FORTRABBIT_API_TOKEN}` if the client
supports env interpolation, rather than pasting the literal value.

**Write availability:** `create_app` / `create_environment` are only enabled in
`local`, `test`, and `develop` environments. Production MCP is **read-only** —
creation returns a "write operations are not enabled" error until the rollout
policy changes. Reads work everywhere.

---

## Step 4 — Use the token with the REST API (`/v1`)

Send the token as a Bearer header on every request. The scheme is literally
`Bearer` — a bare token, `Authorization: Token …`, or a query parameter will not
authenticate.

```sh
curl https://api.fortrabbit.com/v1/apps \
  -H "Authorization: Bearer ${FORTRABBIT_API_TOKEN}" \
  -H "Accept: application/json"
```

The live OpenAPI docs at `/v1/docs` need **no** token (public) and are the
source of truth for available endpoints and payloads. Point the user there to
discover resources. Like MCP, write methods (`POST`/`PATCH`/`DELETE`) on `/v1`
are gated to `local`/`test`/`develop`; in production they return **403**.

---

## Step 5 — Guide the user to generate a token (fallback)

If no token exists, walk the user through creating one — the agent cannot do
this for them:

1. Open **https://dash.fortrabbit.com/you/settings/api-token**.
2. Create a new token and give it a descriptive **name** (a name is required),
   e.g. the machine or agent that will use it.
3. **Copy the token immediately** — it is shown only once and cannot be
   retrieved later. If lost, delete it and create a new one.
4. Provide it back to the agent, and the agent stores it per Step 2.

Ask the user to paste it privately (not into a shared/logged channel). After
storing, confirm back only the masked preview.

---

## Quick reference

| Need | Do this |
|------|---------|
| Find a token | `printenv FORTRABBIT_API_TOKEN`, then grep `.env` for `frbit-at-[0-9a-f]{64}` |
| Store a token | `FORTRABBIT_API_TOKEN` env var or git-ignored `.env` line |
| MCP endpoint | `https://api.fortrabbit.com/mcp`, header `Authorization: Bearer frbit-at-…` |
| REST endpoint | `https://api.fortrabbit.com/v1/…`, header `Authorization: Bearer frbit-at-…` |
| Discover REST resources | `GET /v1/docs` (public, no token) |
| Generate a token | Dashboard → https://dash.fortrabbit.com/you/settings/api-token |
| Mask for display | `frbit-at-…{last4}` — never the full value |

---

## Common errors

| Symptom | Meaning | Fix |
|---------|---------|-----|
| `401` / `Invalid API token` | The token's SHA-256 is unknown — token is wrong, revoked, or truncated | Re-copy the full `frbit-at-…` value; if revoked, generate a new one |
| `401` with no `Authorization` header | Header missing or wrong scheme | Send `Authorization: Bearer <token>` exactly — not `Token`, not a query param |
| `403` on a `POST`/`PATCH`/`DELETE` or MCP create | Authenticated, but writes are disabled in this environment, **or** the resource isn't yours | Writes only run in `local`/`test`/`develop`; otherwise confirm the resource belongs to the token owner |
| `429` | Rate limit — the Public API is throttled per token | Back off and retry after the `Retry-After` header |

---

## Safety rules

- Never print, log, echo, or commit the full token. Display only the masked
  `frbit-at-…{last4}` preview.
- Never store the token in a committed file (`.fortrabbit`, source, `SKILL.md`).
  Use an env var or a git-ignored `.env`.
- Prefer env interpolation (`${FORTRABBIT_API_TOKEN}`) over pasting the literal
  value into commands or MCP config.
- The token acts as the user across all their apps — treat it as a full
  credential, not a scoped read key.
- If a token may have leaked, tell the user to **delete it in the dashboard**
  (revocation is immediate) and generate a replacement.

---

## Response format

```
I'll [one-sentence description of what you're about to do].

[exact command(s) — with the token shown only as ${FORTRABBIT_API_TOKEN} or masked]

Result: [outcome, token masked as frbit-at-…{last4}]

Next step: [one concrete follow-up, e.g. "Call GET /v1/apps to list your apps"]
```
