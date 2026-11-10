# Database: pull, push, connect

The MySQL database of an environment is reachable only from inside the environment or through SSH. Its name and user are the environment ID. The password stays in the dashboard (Environment → MySQL → Access): never ask for it in the chat and never write it to a file.

## Pull: remote → local

The dump runs on the environment, which has the database credentials, so no password is needed and none passes through this machine. Importing it overwrites the local database: say so and wait for a yes.

With the frbit CLI, run it when you have a shell tool; otherwise (claude.ai chat, a sandbox without network) give it to the person to run in their terminal:

```shell
frbit db pull <env> --output /tmp/
```

It writes `/tmp/<env>.sql.gz` (default `./<env>.sql.gz`, so keep `--output` outside the repo), rejects an empty dump, never touches a local database and refuses to overwrite a file without `--force`. Without the argument it uses the environment of the checkout (`frbit link`). `--stdout` writes plain SQL instead. It needs the local `ssh` and an SSH key registered for the person ([ssh.md](ssh.md)); an error naming `dash.fortrabbit.com/new/ssh-key` means the key was rejected or the connection failed.

No frbit, or a CLI without `db pull` (`unknown command "db"`): the plain SSH command, with the IDs filled in:

```shell
ssh <env>@ssh.<region>.frbit.app 'mysqldump --single-transaction --set-gtid-purged=OFF --no-tablespaces "$FORTRABBIT_DB_NAME"' > /tmp/<env>.sql && gzip -f /tmp/<env>.sql
```

The single quotes matter: `$FORTRABBIT_DB_NAME` expands on the environment, not locally. The `&&` stops a failed SSH connection from leaving an empty dump that looks fine; still check that `/tmp/<env>.sql.gz` isn't tiny before importing it.

With a shell, `db-down.sh <env> <region>` does the same with checks: it writes outside the repo, rejects an empty dump and prints the path. Its full path is under Scripts in SKILL.md. Without a shell, give the person the command above, not the script. Exit codes: 3 the environment refused the dump, use the tunnel below; 4 SSH failed (key, network), see [ssh.md](ssh.md); 2 wrong arguments.

Import locally:

| Local setup | Command |
|---|---|
| DDEV | `ddev import-db --file=<dump.sql.gz>` |
| Lando | `lando db-import <dump.sql.gz>` |
| Plain MySQL | `gzip -dc <dump.sql.gz> \| mysql -u<user> -p <database>` |

Then adjust what differs locally: Craft CMS `ddev craft clear-caches/all`; WordPress the site URL, `ddev wp search-replace https://<live> https://<local> --dry-run` first.

## Push: local → remote

Replaces every table that is in the dump; tables that exist only on the environment stay. On production, say which environment, that live data is replaced, and wait for a yes in the user's next message.

1. Back up the remote first with the pull above (`frbit db pull <env> --output /tmp/`, else `db-down.sh <env> <region>` or the ssh command). Keep the path of the dump.
2. Dump locally: `ddev export-db --file=/tmp/local.sql.gz`, or `mysqldump --set-gtid-purged=OFF --no-tablespaces -u<user> -p <database> | gzip > /tmp/local.sql.gz`.
3. Import: `db-up.sh <env> <region> /tmp/local.sql.gz`, by its full path from SKILL.md. It uploads the dump first, then imports on the environment. Exit 5 means the import broke part way: restore the backup from step 1 the same way.
4. Check the site, and tell the person where the backup from step 1 is.

## Through a tunnel

For database clients, and the fallback when the dump above is refused. The person runs the commands that ask for the password, in their own terminal:

```shell
# terminal 1, keep it open
ssh -N -L 13306:mysql:3306 <env>@ssh.<region>.frbit.app

# pull
mysqldump --set-gtid-purged=OFF --no-tablespaces -h127.0.0.1 -P13306 -u<env> -p <env> | gzip > /tmp/<env>.sql.gz

# push: only after the backup (pull) above and a yes; check the file name
gzip -dc /tmp/local.sql.gz | mysql -h127.0.0.1 -P13306 -u<env> -p <env>
```

Database clients such as TablePlus or Sequel Ace use the same tunnel: SSH host `ssh.<region>.frbit.app`, SSH user `<env>`, MySQL host `mysql`, port `3306`, user and database `<env>`.

## Notes

- Dumps hold customer data. Keep them outside the repo, or make sure `*.sql*` is in `.gitignore`, and delete them when done.
- On the environment itself, `ssh <env>@ssh.<region>.frbit.app` and then `mysql` opens a MySQL shell.
- Backups of the environment exist independently of this: the dashboard Backups tab.
