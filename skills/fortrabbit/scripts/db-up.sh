#!/usr/bin/env bash
# shellcheck disable=SC2029 # $staged expands locally on purpose: a fixed path on the environment
# Import a local SQL dump (.sql or .sql.gz) into an environment's MySQL database.
# Every table in the dump is dropped and recreated; tables that exist only on the environment stay.
# Usage: db-up.sh <env-id> <region> <dump-file>
# Run db-down.sh first as a backup. Exit codes: 2 bad arguments, 3 upload refused (use the tunnel in
# database.md), 4 SSH failed (see ssh.md), 5 import failed after it started: restore the backup.
set -euo pipefail

usage="usage: db-up.sh <env-id> <region> <dump-file>"
env_id="${1:?$usage}"
region="${2:?$usage}"
dump="${3:?$usage}"
[[ "$env_id" =~ ^en-[a-z0-9]{6}$ ]] || { echo "not an environment ID: $env_id" >&2; exit 2; }
[[ "$region" =~ ^[a-z0-9-]+$ ]] || { echo "not a region: $region" >&2; exit 2; }
[ -s "$dump" ] || { echo "dump file is missing or empty: $dump" >&2; exit 2; }
case "$dump" in
  *.gz) gzip -t "$dump" || { echo "corrupt gzip file: $dump" >&2; exit 2; } ;;
esac

host="${env_id}@ssh.${region}.frbit.app"
ssh_opts=(-o ConnectTimeout=10 -o BatchMode=yes)
staged="/data/home/fortrabbit-import-$$.sql.gz"

# Upload first, so a dropped connection cannot leave the database half imported.
set +e
case "$dump" in
  *.gz) ssh "${ssh_opts[@]}" "$host" "cat > $staged" < "$dump" ;;
  *) gzip -c "$dump" | ssh "${ssh_opts[@]}" "$host" "cat > $staged" ;;
esac
upload=$?
set -e
if [ "$upload" -eq 255 ]; then echo "ssh to $host failed" >&2; exit 4; fi
if [ "$upload" -ne 0 ]; then echo "upload to $host failed" >&2; exit 3; fi

# shellcheck disable=SC2016 # expands on the environment, not here
remote='gzip -dc '"$staged"' | mysql "$FORTRABBIT_DB_NAME"; status=$?; rm -f '"$staged"'; exit $status'
if ! ssh "${ssh_opts[@]}" "$host" "$remote"; then
  echo "import into $env_id failed part way: the database may be partly overwritten, restore the backup from db-down.sh" >&2
  exit 5
fi
echo "imported $dump into $env_id"
