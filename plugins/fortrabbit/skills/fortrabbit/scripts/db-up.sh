#!/usr/bin/env bash
# shellcheck disable=SC2029 # $staged expands locally on purpose: a fixed path on the environment
# Import a local SQL dump (.sql or .sql.gz) into an environment's MySQL database.
# Every table in the dump is dropped and recreated; tables that exist only on the environment stay.
# Usage: db-up.sh <env-id> <region> <dump-file>
# Run db-down.sh first as a backup. Exit codes: 2 bad arguments, 3 upload refused (use the tunnel in
# database.md), 4 SSH failed (see ssh.md), 5 import failed after it started: restore the backup,
# 6 the uploaded file arrived damaged: nothing was imported.
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
# A connection that dropped during an earlier import left its staged dump behind; clear those first.
stale='rm -f /data/home/fortrabbit-import-*.sql.gz'

# Upload first, so a dropped connection cannot leave the database half imported.
set +e
case "$dump" in
  *.gz) ssh "${ssh_opts[@]}" "$host" "$stale; cat > $staged" < "$dump" ;;
  *) gzip -c "$dump" | ssh "${ssh_opts[@]}" "$host" "$stale; cat > $staged" ;;
esac
upload=$?
set -e
if [ "$upload" -ne 0 ]; then
  ssh "${ssh_opts[@]}" "$host" "rm -f $staged" >/dev/null 2>&1 || true
  if [ "$upload" -eq 255 ]; then echo "ssh to $host failed" >&2; exit 4; fi
  echo "upload to $host failed" >&2
  exit 3
fi

# shellcheck disable=SC2016 # expands on the environment, not here
remote='gzip -t '"$staged"' || { rm -f '"$staged"'; exit 6; }; gzip -dc '"$staged"' | mysql "$FORTRABBIT_DB_NAME"; status=$?; rm -f '"$staged"'; exit $status'
set +e
ssh "${ssh_opts[@]}" "$host" "$remote"
import=$?
set -e
if [ "$import" -eq 6 ]; then echo "the upload arrived damaged, nothing was imported: run db-up.sh again" >&2; exit 6; fi
if [ "$import" -ne 0 ]; then
  echo "import into $env_id failed part way: the database may be partly overwritten, restore the backup from db-down.sh" >&2
  exit 5
fi
echo "imported $dump into $env_id"
