#!/usr/bin/env bash
# Builds the ZIP for the OpenAI plugin directory from the committed files.
# Usage: .github/scripts/build-openai-zip.sh [output.zip]
# Prints the path of the ZIP. Leaves out the Claude manifest so the upload reads .codex-plugin only.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

plugin=plugins/fortrabbit
# The listing icon is whatever the OpenAI manifest names as its logo.
logo=$(jq -r '.interface.logo | sub("^\\./"; "")' "$plugin/.codex-plugin/plugin.json")
paths=(.codex-plugin .mcp.json skills "$logo" README.md LICENSE)
tracked=("${paths[@]/#/$plugin/}")

# git archive packs HEAD, so uncommitted edits and new files would silently be missing from the upload.
if ! git diff --quiet HEAD -- "${tracked[@]}" || [ -n "$(git ls-files --others --exclude-standard -- "${tracked[@]}")" ]; then
  echo "uncommitted changes or untracked files in the packaged paths; commit them first" >&2
  exit 1
fi

.github/scripts/check-manifests.sh >&2

out="${1:-dist/fortrabbit-openai-$(tr -d '[:space:]' < VERSION).zip}"
[[ "$out" == *.zip ]] || { echo "usage: build-openai-zip.sh [output.zip]" >&2; exit 2; }
mkdir -p "$(dirname "$out")"
# Archiving the plugin folder's tree puts its files at the root of the ZIP, where OpenAI expects them.
git archive --format=zip --output="$out" "HEAD:$plugin" -- "${paths[@]}"
echo "$out"
