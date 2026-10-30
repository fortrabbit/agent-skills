# Troubleshooting: is it live, HTTP errors

Most errors come from the app, its configuration or its last deployment, not from the platform. Look before changing anything, and change nothing on production without a yes.

## Is it live?

```shell
curl -sL -o /dev/null -w "%{http_code} %{time_total}s %{url_effective}\n" https://<domain>
curl -sI https://<domain> | head -20
```

`<domain>` is the main domain from `list_domains` (`isMain`): a custom domain, a cloud domain `<label>.frbit.cloud`, or the default domain `<env>.<region>.frbit.app`. The default domain forwards to the main domain, so check with `-L`.

## First three checks, for every error

1. **Deployments**: `list_deployments` with `environmentPublicId` and `limit: 1` → the newest for the environment. Failed or still running? `get_deployment_logs`. A failed post deploy command means new code runs without its migration: [deploy.md](deploy.md).
2. **What changed**: `git log -5 --oneline` on the connected branch, and `get_environment` for recent changes to variables and root path. The PHP version is on the dashboard PHP page, not in MCP.
3. **Logs**: the dashboard Logs tab (`https://dash.fortrabbit.com/environments/<env>/logs`) holds the PHP, Apache access, Apache error and jobs logs. There is no API for them yet: ask the person to filter for `ERROR` and paste the lines. The software templates send Laravel, Statamic and Craft CMS logs to `stderr`, so they show up there too. Log files exist only when the app writes them, for example WordPress with `WP_DEBUG_LOG`: `ssh <env>@ssh.<region>.frbit.app 'tail -n 80 wp-content/debug.log'`.

## By status code

| Code | Usually | Look at |
|---|---|---|
| 404 on every page | Wrong root path, or nothing deployed yet | Root path setting (`web` for Craft CMS 4 and 5, `public` for Craft CMS 6, Laravel, Statamic and Symfony, the code root for Kirby and WordPress); `ssh … 'ls -la'` |
| 404 on some pages | Missing `.htaccess` or rewrite rules | Apache error log; `.htaccess` in the root path |
| 500 | PHP error: exception, missing env var (`APP_KEY`, `CRAFT_SECURITY_KEY`, database), failed migration, wrong PHP version | PHP log, last deployment log, `get_environment` variables, the dashboard PHP version against `composer.json` |
| 503 | PHP busy or crashing: memory exhausted, a plugin killing the process, slow requests piling up | PHP log, metrics tab for memory and swap; a restart only buys time |
| 504 | Requests too slow: heavy queries, external API calls, image transforms, bots on uncached URLs | Access log for the slow URLs and clients, metrics for response times |

## Restart

`frbit environments restart <env>` clears a stuck PHP pool and applies changed variables. Ask first on production, and say it does not fix the cause.

## Platform status

`https://fortrabbit.betteruptime.com` before blaming the app for an outage that hits several sites at once.
