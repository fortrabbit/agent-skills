#!/usr/bin/env bash
# Dump an environment's MySQL database to a gzipped local file.
# Usage: db-down.sh <env-id> <region> [output-file]
# Prints the path of the dump. Exit codes: 2 bad arguments, 3 the environment refused the dump
# (use the tunnel in database.md), 4 SSH failed (key, network: see ssh.md), 1 local error.
set -euo pipefail

usage="usage: db-down.sh <env-id> <region> [output-file]"
env_id="${1:?$usage}"
region="${2:?$usage}"
[[ "$env_id" =~ ^en-[a-z0-9]{6}$ ]] || { echo "not an environment ID: $env_id" >&2; exit 2; }
[[ "$region" =~ ^[a-z0-9-]+$ ]] || { echo "not a region: $region" >&2; exit 2; }

out="${3:-${TMPDIR:-/tmp}/fortrabbit-${env_id}-$(date +%Y%m%d-%H%M%S).sql.gz}"
host="${env_id}@ssh.${region}.frbit.app"
tmp="${out}.part"
trap 'rm -f "$tmp"' EXIT

# The dump runs on the environment, which holds the database credentials, so none pass through this machine.
# shellcheck disable=SC2016 # expands on the environment, not here
remote='mysqldump --single-transaction --set-gtid-purged=OFF --no-tablespaces "$FORTRABBIT_DB_NAME"'

set +e
ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" "$remote" | gzip > "$tmp"
status=("${PIPESTATUS[@]}")
set -e

if [ "${status[0]}" -eq 255 ]; then echo "ssh to $host failed" >&2; exit 4; fi
if [ "${status[0]}" -ne 0 ]; then echo "mysqldump failed on $host" >&2; exit 3; fi
if [ "${status[1]}" -ne 0 ]; then echo "could not write $tmp" >&2; exit 1; fi
if [ "$(gzip -dc "$tmp" | head -c 4096 | wc -c)" -lt 100 ]; then echo "dump from $host is empty" >&2; exit 3; fi

mv "$tmp" "$out"
echo "$out"
