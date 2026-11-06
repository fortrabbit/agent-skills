#!/usr/bin/env bash
# Runs the eval suite in evals/ against a temporary copy of the plugin. The suite lives outside
# plugins/fortrabbit/ so the directory scan reads only what users install, and `claude plugin eval`
# only reads an eval dir inside the plugin root.
# Usage: .github/scripts/eval.sh [claude plugin eval options], e.g. --case list-apps --runs 1
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
root=$PWD

for arg in "$@"; do
  case $arg in
    --output-dir* | --report*) echo "eval.sh sets --output-dir and --report itself" >&2; exit 2 ;;
  esac
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp -RL plugins/fortrabbit "$tmp/fortrabbit"
rsync -aL --exclude /results/ evals/ "$tmp/fortrabbit/evals/"

out="$root/evals/results/$(date -u +%Y-%m-%dT%H-%M-%SZ)-$$"
mkdir -p "$out"
claude plugin eval "$tmp/fortrabbit" --output-dir "$out" --report "$out/report.html" "$@"
