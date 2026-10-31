---
type: llm
---

PASS if the reply gives wp-config.php code that sets DB_NAME, DB_USER, DB_PASSWORD and DB_HOST from the FORTRABBIT_DB_* environment variables (with getenv or $_ENV/$_SERVER) with a local fallback such as the DDEV value "db", and sets WP_HOME and WP_SITEURL from FORTRABBIT_MAIN_DOMAIN with an https:// prefix when it is set.
FAIL if it hard-codes the live database credentials, invents other variable names (such as DB_HOST env vars without the FORTRABBIT_ prefix, or MYSQL_*), or asks the person to paste the database password.
