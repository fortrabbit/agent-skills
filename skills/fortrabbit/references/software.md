# Software: detection, templates, local development

When an app is created, fortrabbit applies a software template: root path, environment variables in the names the software expects (mapped from the platform's `FORTRABBIT_DB_*` and `FORTRABBIT_MAIN_DOMAIN`), build and post deploy commands. Read the live values with `get_environment` instead of assuming them. `list_software_presets` lists what is supported.

## Detect the software

First match wins:

1. `wp-config.php` or `wp-content/` → WordPress
2. `craftcms/cms` in `composer.json` → Craft CMS (version 6 is built on Laravel)
3. `statamic/cms` → Statamic
4. `getkirby/cms` → Kirby
5. `laravel/framework` or an `artisan` file → Laravel
6. `symfony/framework-bundle` → Symfony
7. Any other `composer.json` → plain PHP

With a GitHub repo, `detect_repository_stack` gives the matching preset directly.

## Per software

| Software | Root path | Post deploy commands (template) | Production settings |
|---|---|---|---|
| Laravel | `public` | `php artisan migrate --force` | `APP_ENV=production`, `APP_DEBUG=false`, `APP_KEY` set by the template |
| Craft CMS 4, 5 | `web` | `php craft migrate/all`, `php craft project-config/apply`, `php craft clear-caches/all` | `CRAFT_ENVIRONMENT`, `CRAFT_DEV_MODE=false`, `CRAFT_ALLOW_ADMIN_CHANGES=false`, `CRAFT_SECURITY_KEY` |
| Craft CMS 6 | `public` | `php artisan migrate --force`, `php artisan craft:up`, `php artisan craft:clear-caches` | Laravel-style `APP_*` variables |
| Statamic | `public` | `php artisan migrate --force` | `APP_*` like Laravel |
| Kirby | code root | `rm -rf site/cache/*/pages` | `APP_MODE`, `APP_DEBUG` |
| Symfony | `public` | `cache:clear`, `assets:install public`, `doctrine:migrations:migrate` | `APP_ENV`, `APP_DEBUG`, `APP_SECRET`, `DATABASE_URL` |
| WordPress | code root | none | reads its own `wp-config.php` |

A debug switch depends on the software: Laravel and Statamic use `APP_DEBUG`, Craft CMS 4 and 5 use `CRAFT_DEV_MODE`, not `APP_DEBUG`. When the person names a variable the software does not read, say so and ask which one to set. Change it with `update_environment`, then restart or deploy: [mcp.md](mcp.md).

## Notes per software

- **Craft CMS**: project config in `config/project/` deploys with git; content and assets do not. Volumes on local disk need [files.md](files.md); the database needs [database.md](database.md).
- **Statamic, Kirby**: content is flat files. If it is edited on the live site, pull it before deploying, or commit it from the live site, or the next deployment overwrites it: [files.md](files.md).
- **WordPress**: usually deployed by rsync, not git. Let `wp-config.php` read the platform variables so one file works locally and live:

  ```php
  define('DB_NAME',     getenv('FORTRABBIT_DB_NAME')     ?: 'db');
  define('DB_USER',     getenv('FORTRABBIT_DB_USER')     ?: 'db');
  define('DB_PASSWORD', getenv('FORTRABBIT_DB_PASSWORD') ?: 'db');
  define('DB_HOST',     getenv('FORTRABBIT_DB_HOST')     ?: 'db');
  if ($domain = getenv('FORTRABBIT_MAIN_DOMAIN')) {
      define('WP_HOME', 'https://' . $domain);
      define('WP_SITEURL', 'https://' . $domain);
  }
  ```

  Show the diff and ask before editing an existing `wp-config.php`.

## Local development

Detect what exists before suggesting anything: `.ddev/config.yaml` (DDEV), `.lando.yml` (Lando), `docker-compose.yml`, `.devcontainer/`, Laravel Herd or Valet. DDEV is the common choice for Craft CMS, WordPress and Laravel:

```shell
ddev config --project-type=craftcms --docroot=web    # laravel, wordpress, php …
ddev start
```

Kirby and Statamic without a database also run on `php -S localhost:8000 -t public` (Kirby: without `-t`).

New project from scratch: install the software locally first (`composer create-project craftcms/craft .`, `laravel new`, …), commit it, then continue with [boarding.md](boarding.md).
