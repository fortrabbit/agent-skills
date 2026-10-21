# Browser review: test your changes

After making changes to your fortrabbit environment, review them in a browser using the test domain.

## Test domain URL

```text
https://APP_ENV_ID.REGION.frbit.app
```

Always include the region segment.  
Example: `https://en-0rk7ap.eu-w1a.frbit.app`.  
The TLD is `frbit.app`. Do not use `frb.io` or `frb.app` — both are wrong.

## Pre-test with curl

Before asking the user to open a browser, run a quick HTTP check:

```shell
curl -o /dev/null -s -w "%{http_code}" https://APP_ENV_ID.REGION.frbit.app
```

Act on the result using this decision tree:

```
IF status == 200
  → Site is up. Say: "Your site is responding. Open it in a browser to review:
      https://APP_ENV_ID.REGION.frbit.app"

ELSE IF status == 301 OR 302
  → Run: curl -sI -L https://APP_ENV_ID.REGION.frbit.app | grep -E "^(HTTP|Location)"
    Show the redirect chain. Ask: "Is this redirect expected?"

ELSE IF status == 404
  → Say: "Page not found. Possible causes:
      1. Deployment not complete yet — check the deployment log in the dashboard
      2. Public root misconfigured — default is htdocs/
      3. .htaccess missing or incorrect"
    Ask: "Want me to check the remote files? I can run:
      ssh APP_ENV_ID@ssh.REGION.frbit.app 'ls -la htdocs/'"

ELSE IF status == 500
  → Load http-error-troubleshooting.md and follow the 500 section.

ELSE IF status == 502 OR 503
  → Load http-error-troubleshooting.md and follow the 503 section.

ELSE IF status == 504
  → Load http-error-troubleshooting.md and follow the 504 section.

ELSE IF curl times out OR produces no output
  → Say: "No response from the server. Checking SSH connectivity first."
    Run: ssh -o ConnectTimeout=10 APP_ENV_ID@ssh.REGION.frbit.app echo ok
    IF SSH succeeds → Say: "SSH works, so the platform is reachable. The app may still be deploying or starting up. Wait 30 seconds and try again."
    IF SSH fails    → Load connect.md and troubleshoot the SSH connection.
```

For a more detailed response (headers, redirect chain):

```shell
curl -I -L https://APP_ENV_ID.REGION.frbit.app
```

## When to use test domain

Use after any code deployment, SSH exec, content sync, or database operation.

For more details, see the [fortrabbit test domain documentation](https://docs.fortrabbit.com/platform/domains/test-domain).