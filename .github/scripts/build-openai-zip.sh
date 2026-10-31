#!/usr/bin/env bash
# Builds the ZIP for the OpenAI plugin directory from the committed files.
# Usage: .github/scripts/build-openai-zip.sh [output.zip]
# Prints the path of the ZIP. Leaves out the Claude manifest so the upload reads .codex-plugin only.
set -euo pipefail
out="${1:-}"
[ -z "$out" ] || [[ "$out" == *.zip ]] || { echo "usage: build-openai-zip.sh [output.zip]" >&2; exit 2; }
# A relative output path is relative to where the script was called, not to the repo root.
[ -z "$out" ] || [[ "$out" == /* ]] || out="$PWD/$out"
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

plugin=plugins/fortrabbit
# The listing icons are whatever the OpenAI manifest names, without duplicates.
mapfile -t icons < <(jq -r '[.interface.logo, .interface.composerIcon] | map(sub("^\\./"; "")) | unique[]' "$plugin/.codex-plugin/plugin.json")
paths=(.codex-plugin .mcp.json skills "${icons[@]}" README.md LICENSE)
tracked=("${paths[@]/#/$plugin/}")

# git archive packs HEAD, so uncommitted edits and new files would silently be missing from the upload.
if ! git diff --quiet HEAD -- "${tracked[@]}" || [ -n "$(git ls-files --others --exclude-standard -- "${tracked[@]}")" ]; then
  echo "uncommitted changes or untracked files in the packaged paths; commit them first" >&2
  exit 1
fi

.github/scripts/check-manifests.sh >&2

out="${out:-$PWD/dist/fortrabbit-openai-$(tr -d '[:space:]' < VERSION).zip}"
mkdir -p "$(dirname "$out")"
# Archiving the plugin folder's tree puts its files at the root of the ZIP, where OpenAI expects them.
git archive --format=zip --output="$out" "HEAD:$plugin" -- "${paths[@]}"
echo "$out"
