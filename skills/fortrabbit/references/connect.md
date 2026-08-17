# Connect: Start using fortrabbit

## Step 1 — Do you have a fortrabbit account?

Ask the user:

> "Do you have a fortrabbit account?"

- **No account yet:** Direct them to sign up at [dash.fortrabbit.com/signup](https://dash.fortrabbit.com/signup) — there is a free trial, no credit card required to start. Then say: "Let me know when you're signed up and I'll continue." Wait for the user to confirm before proceeding.
- **Yes:** Continue to Step 2.

---

## Step 2 — Do you have an app?

Ask the user:

> "Do you already have an app on fortrabbit?"

- **No app yet:** Either create one at [dash.fortrabbit.com/new/app](https://dash.fortrabbit.com/new/app), or — if an MCP server is configured — create it via MCP's `create_app`. Resolve the region, software preset, and component sizes with the `list_*` tools first, then show the user the full configuration **including the monthly price** and get explicit confirmation before calling it (see mcp.md). If creating in the dashboard instead, say: "Let me know when the app is created — the dashboard will show the environment ID and region you'll need next." Wait for the user to confirm before proceeding.
- **Yes:** Continue to Step 3.

---

## Step 3 — Find your app environment ID and region

**If an MCP server is configured, look both values up automatically** instead of asking the user to hunt for them: call `list_apps`/`list_environments` and use the environment `publicId` (`en-…`) as the app-env-id, then `get_app` for the app's `region`. Confirm both with the user before writing them. See mcp.md.

If no MCP server is configured, connecting one takes a single command — see the `fortrabbit-api-access` skill.

Otherwise, both values are shown in the fortrabbit dashboard on the environment page, next to the SSH access details.

- The app environment ID is a short random string, for example: `en-wjl0ai`
- The region is a location code, for example: `eu-w1a` or `us-e1a`

Full SSH address: `en-xxxxxx@ssh.xxxxxx.frbit.app`

---

## Step 4 — Save the config locally

Create a `.fortrabbit` file in your project root, if not already present:

```
app-env-id=en-xxxxxx
region=eu-w1a
```

This file contains no secrets and can safely be committed to Git.

---

## Step 5 — Test the SSH connection

```shell
# Replace APP_ENV_ID and REGION with your values
ssh -o ConnectTimeout=10 APP_ENV_ID@ssh.REGION.frbit.app echo "Connection OK"
```

A successful connection prints the fortrabbit welcome banner followed by "Connection OK".

If the connection fails, classify the error:

```
IF error contains "Permission denied (publickey)"
  → Load ssh-key-setup.md (SSH public key is missing or not registered in the dashboard)

ELSE IF error contains "Connection timed out" OR "Connection refused" OR "Network is unreachable"
  → Tell the user: "Could not reach fortrabbit. Check:
      1. Is your internet connected?
      2. Is port 22 blocked by a firewall or VPN?
      3. Is the region correct? You entered: REGION"
  Ask: "Which of these might be the issue?"

ELSE (any other error)
  → Show the full error output and say: "Something unexpected happened. Here's the error: [ERROR]. What do you see?"
```

---

## Step 6 — Continue to software setup

```
IF software stack was already detected (via start.md or visible project files)
  → Load the matching guide directly:
    WordPress    → wordpress.md
    Craft CMS    → craft-cms.md
    Statamic     → statamic.md
    Kirby        → kirby-cms.md
    Laravel      → deploy.md
    Generic PHP  → deploy.md

ELSE IF no software was detected yet (project files exist but type is unknown)
  → Load software-detection.md now, then return and load the matching guide above

ELSE IF folder is empty (no project files at all)
  → Ask: "Which software would you like to use?
      - WordPress
      - Craft CMS
      - Kirby
      - Statamic
      - Laravel
      - Other PHP"
    Load the matching guide from the list above (it will walk through local installation first)
```
