#!/usr/bin/env bash
# Builds the ZIP for the OpenAI plugin directory from the committed files.
# Usage: .github/scripts/build-openai-zip.sh [output.zip]
# Prints the path of the ZIP. Leaves out the Claude manifests so the upload reads .codex-plugin only.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

paths=(.codex-plugin .mcp.json skills .claude-plugin/icon.png README.md LICENSE)

# git archive packs HEAD, so uncommitted edits and new files would silently be missing from the upload.
if ! git diff --quiet HEAD -- "${paths[@]}" || [ -n "$(git ls-files --others --exclude-standard -- "${paths[@]}")" ]; then
  echo "uncommitted changes or untracked files in the packaged paths; commit them first" >&2
  exit 1
fi

.github/scripts/check-manifests.sh >&2

out="${1:-dist/fortrabbit-openai-$(tr -d '[:space:]' < VERSION).zip}"
[[ "$out" == *.zip ]] || { echo "usage: build-openai-zip.sh [output.zip]" >&2; exit 2; }
mkdir -p "$(dirname "$out")"
git archive --format=zip --output="$out" HEAD -- "${paths[@]}"
echo "$out"
