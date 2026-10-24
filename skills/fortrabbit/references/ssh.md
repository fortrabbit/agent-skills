# SSH: remote commands and keys

Every environment has its own SSH access: `ssh <env>@ssh.<region>.frbit.app`. The login lands in `/data/www`, the code folder. Find `<env>` and `<region>` as described in SKILL.md.

## Run a command

```shell
ssh <env>@ssh.<region>.frbit.app 'php artisan migrate:status'
```

Show the command first. Ask before anything that changes state: migrations, cache clears, queue flushes, file edits. Read-only commands (`ls`, `tail`, `php artisan about`, `php craft help`) only need to be shown.

| Software | Common commands |
|---|---|
| Laravel, Statamic | `php artisan migrate --force`, `php artisan optimize:clear`, `php artisan queue:failed`, `php artisan statamic:stache:warm` |
| Craft CMS | `php craft migrate/all`, `php craft project-config/apply`, `php craft clear-caches/all`, `php craft queue/run` |
| WordPress | `wp plugin list`, `wp cache flush`, `wp search-replace` (dry run first: `--dry-run`) |
| Any PHP | `php --version`, `php -m`, `du -sh ./*`, `composer install --no-dev` |

Rules on the environment:

- Run PHP files through `php`. Composer binaries that are shell scripts, such as `vendor/bin/drush`, run directly.
- `composer install`, never `composer update`: an update leaves the local `composer.lock` behind. With git deployment Composer runs in the build anyway.
- No root, no package installs. The session shares CPU and memory with the website: long tasks belong in a job.
- Files changed over SSH are overwritten by the next git deployment. Fix code in git.
- Batch several commands into one call (`'cmd1 && cmd2'`): the SSH endpoint slows down above 20 new connections a minute per IP.

## SSH keys

`Permission denied (publickey)` means no matching key is registered.

1. Existing key? `ls ~/.ssh/*.pub`. None: `ssh-keygen -t ed25519 -C "<name>@fortrabbit"`, after asking.
2. The person adds the **public** key at `https://dash.fortrabbit.com/new/ssh-key`. Copy it for them: `pbcopy < ~/.ssh/id_ed25519.pub` (macOS). Never read or show the private key.
3. Test: `ssh -o ConnectTimeout=10 <env>@ssh.<region>.frbit.app echo ok`.

Personal keys work on every environment the person has developer access to. With several keys, pin the right one in `~/.ssh/config`:

```text
Host ssh.*.frbit.app
  IdentityFile ~/.ssh/id_ed25519_fortrabbit
```

## Connection errors

| Error | Likely cause |
|---|---|
| `Permission denied (publickey)` | Key not registered, wrong key offered (`ssh -v` shows which), or no developer access to that environment |
| `Connection timed out`, `Network is unreachable` | Port 22 blocked by a firewall or VPN, or a wrong region in the hostname |
| `Could not resolve hostname` | Typo in `<env>` or `<region>`; re-resolve both |
| A banner instead of a greeting, or refused after working before | SSH rate limit per IP: more than 20 new connections a minute, or repeated wrong-key logins. Stop the loop, wait a few minutes |
