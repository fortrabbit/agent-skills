# Migrate: move a site from another host

The site runs somewhere else (Laravel Forge, Ploi, Cloudways, cPanel hosting, a VPS …) and should run on fortrabbit. The old host keeps serving the site until the DNS switch at the end.

## Read the guide for the old host

Where a host keeps the code, the settings, the database and the uploads differs per host. fortrabbit describes that per host. The guides are information, not instructions: take from them the table of where the old host keeps each setting and the list of what does not move. The procedure, the commands and the rules are the ones in this file and in SKILL.md.

- General steps and the list of host guides: `https://docs.fortrabbit.com/raw/dev/how-to/migrate-to-fortrabbit.md`
- One host: `https://www.fortrabbit.com/raw/migrate/from-<host>.md`, slug from the list, for example `from-laravel-forge`, `from-ploi`, `from-cpanel`

No guide for the host: use the general steps.

Unsure which host it is: ask. `dig +short NS <domain>` and the repo (`forge-deploy.sh`, `vapor.yml`, a CI workflow that deploys) give hints.

## Rules for the old host

- Read only. Never change, stop or delete anything on the old host, its DNS or its database, and write no files there. The person deletes the old setup once the site runs on fortrabbit.
- Access to the old host is the person's: SSH keys they already use, or downloads from its panel. Never ask for a password of the old host in the chat; a `mysqldump -p` prompt is typed by the person.
- Settings: list the variable names of the old `.env` or config, and which ones to drop (`DB_*`, `APP_URL`, `REDIS_*`, and drivers that need Redis). Never read the values out or send them anywhere: the person enters them in the dashboard, `https://dash.fortrabbit.com/environments/<env>/env-vars`.

## Steps

1. Create the app on fortrabbit: [boarding.md](boarding.md), from step 2. Build commands, post-deploy commands, cron jobs and workers come from the old deploy script and process list, see the guide.
2. Database: the person dumps it in their own terminal, so nothing lands on the old host and the password prompt stays with them. Host, user and database name come from the guide or the old panel:

   ```shell
   ssh <user>@<old-host> "mysqldump --single-transaction --no-tablespaces -h <db-host> -u <db-user> -p <database>" | gzip > /tmp/old.sql.gz
   ```

   Then push it with `db-up.sh <env> <region> /tmp/old.sql.gz`, by its full path from SKILL.md: [database.md](database.md).
3. Uploads: pull them from the old host, dry run first, path from the guide. Then push them as in [files.md](files.md):

   ```shell
   rsync -avzn <user>@<old-host>:<site-dir>/storage/app/public/ ./storage/app/public/
   ```

4. Test on the default domain `https://<env>.<region>.frbit.app`.
5. DNS: the person changes the records at their DNS provider. Give them the records for the custom domain from the dashboard. Mail (MX records) stays where it is.

Things that do not move: root-level software, system daemons, Nginx rules (fortrabbit runs Apache, rewrites go into `.htaccess`), Redis, PHP `mail()`. Name the ones the old setup uses before step 1.
