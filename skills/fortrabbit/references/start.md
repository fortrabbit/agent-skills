# Start — detect project state and ask about intent

This reference is loaded when the user invokes the skill with no specific intent. This is usually the first step.

---

## Definitions

Before routing, evaluate these four conditions:

- **software detected** — at least one signal from `software-detection.md` matches (see that file for the full ordered check list)
- **fortrabbit configured** — `.fortrabbit` file exists in the project root, OR `.env` contains `FORTRABBIT_APP_ENV_ID`. (If neither exists but an MCP server is configured, you can discover the user's apps/environments via MCP `list_apps`/`list_environments` rather than treating the project as unconfigured — see mcp.md.)
- **git ready** — ALL of the following are true:
  - `git rev-parse --git-dir` succeeds (repo exists)
  - `git remote get-url origin` returns a URL
  - either `git status --porcelain` is empty, or the user has acknowledged uncommitted changes
- **git absent** — `.git/` does not exist in the project root
- **git partial** — repo exists (`git rev-parse --git-dir` succeeds) but no `origin` remote is set

---

## Step 1 — Detect the software stack

Run this detection script:

```shell
if [ -f composer.json ]; then
  grep -q 'craftcms/cms' composer.json && echo "Craft CMS"
  grep -q 'statamic/cms' composer.json && echo "Statamic"
  grep -q 'getkirby/cms' composer.json && echo "Kirby"
  grep -q 'laravel/framework' composer.json && echo "Laravel"
  echo "PHP project (composer.json present)"
fi
[ -f wp-config.php ] && echo "WordPress"
[ -d wp-content ] && echo "WordPress (wp-content)"
[ -f artisan ] && echo "Laravel (artisan)"
[ -f bin/craft ] && echo "Craft CMS (bin/craft)"
[ -d site/plugins ] && echo "Kirby (site/plugins)"
```

Apply this priority order (first match wins):

```
1. wp-config.php OR wp-content/ → WordPress
2. craftcms/cms in composer.json OR bin/craft → Craft CMS
3. statamic/cms in composer.json → Statamic
4. getkirby/cms in composer.json OR site/plugins/ → Kirby
5. laravel/framework in composer.json OR artisan at root → Laravel
6. composer.json exists (none above matched) → Generic PHP
7. No signals → Ask: "I couldn't detect a PHP project here. What are you using?
     (WordPress / Craft CMS / Kirby / Statamic / Laravel / Other PHP)"
```

If detection is ambiguous or signals conflict, load `software-detection.md` for deeper investigation.

---

## Step 2 — Check project and Git state

Run:

```shell
# Check fortrabbit config
[ -f .fortrabbit ] && cat .fortrabbit || echo "no .fortrabbit"
grep -s 'FORTRABBIT_APP_ENV_ID' .env 2>/dev/null && echo ".env has app-env-id" || true

# Check git state
git rev-parse --git-dir 2>/dev/null && echo "git repo" || echo "no git repo"
git remote get-url origin 2>/dev/null && echo "origin: $(git remote get-url origin)" || echo "no origin remote"
git status --porcelain 2>/dev/null | head -5
```

Use the results to evaluate the four conditions defined above.

---

## Step 3 — Summarize and route

Present a one-paragraph status summary based on all findings. Example:

> "This looks like a **Craft CMS** project. fortrabbit is configured (`app-env-id: en-wjl0ai`, region: `eu-w1a`). Git is initialized with a GitHub remote. You're ready to deploy."

Then route using this decision tree (evaluate in order, first match wins):

```
IF NOT software detected AND NOT fortrabbit configured
  → Load connect.md from Step 1 (full onboarding — account, app, SSH)

ELSE IF software detected AND NOT fortrabbit configured
  → Load connect.md from Step 3 (skip account/app creation, go straight to app-env-id lookup)

ELSE IF fortrabbit configured AND NOT software detected
  → Load software-detection.md, then return here and re-evaluate

ELSE IF fortrabbit configured AND software detected
  IF git ready
    → Show summary and say: "You're ready to deploy."
      Suggest: /fortrabbit deploy

  ELSE IF git absent
    → Ask: "No Git repo found. Do you want to:
        A) Set up Git deployment (connects GitHub → fortrabbit)
        B) Use rsync to sync files directly (no Git required)"
      IF A → Load setup-git-github.md
      IF B → Load sync.md

  ELSE IF git partial (repo exists but no origin remote)
    → Load setup-git-github.md starting at the step for adding a GitHub remote
```
