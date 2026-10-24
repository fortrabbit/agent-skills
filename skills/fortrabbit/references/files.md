# Files: content and full sync with rsync

Git deploys code. Uploads, images and flat-file content live only on the environment and move with rsync over SSH. Remote paths are relative to the login folder `/data/www`.

## Rules

- Show the full command. Run a dry run (`-n`) first for any first sync to a path and for anything with `--delete`, show what would change, then ask.
- Pulling overwrites local files, pushing overwrites remote ones. Say which and wait for a yes.
- Trailing slashes matter: `./dir/ host:./dir/` syncs the contents of `dir`. Keep both sides the same shape.
- Never sync `.env`, `.git/`, `node_modules/` or local caches.

## Content folders per software

| Software | Folders |
|---|---|
| Laravel | `storage/app/public/` |
| Craft CMS | The local volume paths: `grep -rn "path\|basePath" config/project/fs config/project/volumes 2>/dev/null`, often `web/uploads/`. Volumes on S3 need no sync. |
| Statamic | `content/`, `users/`, `public/assets/`, `resources/blueprints/`, `resources/fieldsets/`, `resources/forms/`, `storage/forms/`, those that exist |
| Kirby | `content/`, `site/accounts/` only when asked, `media/` can be regenerated |
| WordPress | `wp-content/uploads/` |

```shell
# pull
rsync -avz <env>@ssh.<region>.frbit.app:./web/uploads/ ./web/uploads/
# push, dry run first
rsync -avzn ./web/uploads/ <env>@ssh.<region>.frbit.app:./web/uploads/
```

## Full sync without git

For projects that do not deploy from git, typically WordPress or a quick demo. Pushes the whole project including `vendor/`.

```shell
rsync -avzn \
  --exclude='.git/' --exclude='.env' --exclude='.env.*' --exclude='.ddev/' \
  --exclude='.claude/' --exclude='.agents/' --exclude='node_modules/' --exclude='.DS_Store' \
  ./ <env>@ssh.<region>.frbit.app:./
```

Drop `-n` after the person confirms the preview. A full pull is `rsync -avz <env>@ssh.<region>.frbit.app:./ ./` with the same excludes.

An environment that also deploys from git gets the synced code overwritten by the next deployment.
