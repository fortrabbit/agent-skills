#!/usr/bin/env bash
# Checks the Claude and OpenAI plugin manifests against each other and against the limits
# of the OpenAI plugin directory, which an upload only reports after the fact.
# Usage: .github/scripts/check-manifests.sh   (needs jq)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

plugin=plugins/fortrabbit
claude=$plugin/.claude-plugin/plugin.json
openai=$plugin/.codex-plugin/plugin.json
status=0
fail() { echo "FAIL: $*" >&2; status=1; }

while IFS= read -r file; do
  [ -f "$file" ] || continue
  jq -e . "$file" >/dev/null 2>&1 || fail "$file is not valid JSON"
done < <(git ls-files --cached --others --exclude-standard '*.json')
[ "$status" -eq 0 ] || exit 1

version=$(tr -d '[:space:]' < VERSION)
skill_version=$(sed -n 's/^  version: "\(.*\)"$/\1/p' $plugin/skills/fortrabbit/SKILL.md)
for found in "$(jq -r .version "$claude")" "$(jq -r .version "$openai")" "$skill_version"; do
  [ "$found" = "$version" ] || fail "version $found does not match VERSION $version (check $claude, $openai, SKILL.md)"
done
for key in name description author homepage repository license keywords; do
  [ "$(jq -c ".$key" "$claude")" = "$(jq -c ".$key" "$openai")" ] || fail "$key differs between $claude and $openai"
done
[ "$(jq -r .privacyPolicyUrl "$claude")" = "$(jq -r .interface.privacyPolicyURL "$openai")" ] || fail "privacy URL differs between $claude and $openai"
[ "$(jq -r .description "$claude")" = "$(jq -r '.plugins[0].description' .claude-plugin/marketplace.json)" ] || fail "description differs between $claude and .claude-plugin/marketplace.json"
[ "$(jq -r '.plugins[0].source' .claude-plugin/marketplace.json)" = "./$plugin" ] || fail "the marketplace entry must point at ./$plugin"
cmp -s LICENSE "$plugin/LICENSE" || fail "LICENSE and $plugin/LICENSE differ"

# OpenAI connects exactly one MCP server per plugin.
[ "$(jq '.mcpServers | length' "$plugin/.mcp.json")" -eq 1 ] || fail "$plugin/.mcp.json must declare exactly one server"

for path in $(jq -r '.skills, .mcpServers, .interface.composerIcon, .interface.logo' "$openai"); do
  [ -e "$plugin/$path" ] || fail "$openai points at $path, which does not exist"
done

# Submission limits of the OpenAI plugin directory, listing metadata section.
problems=$(jq -r '
  .interface as $i
  | ($i.defaultPrompt // [] | if type == "string" then [.] else . end) as $prompts
  | (if ($i.displayName | length) > 30 then "displayName is longer than 30 characters" else empty end),
    (if ($i.shortDescription | length) > 30 then "shortDescription is longer than 30 characters" else empty end),
    (if ($i.longDescription | length) > 4000 then "longDescription is longer than 4000 characters" else empty end),
    (if ($prompts | length) > 3 then "more than 3 defaultPrompt entries" else empty end),
    ($prompts[] | select(length > 128) | "defaultPrompt longer than 128 characters: \(.)"),
    ([$i.websiteURL, $i.supportURL, $i.privacyPolicyURL, $i.termsOfServiceURL][] | select(. == null or (startswith("https://") | not)) | "a listing URL is missing or not https"),
    (.extensions["com.openai"].review.test_cases // empty
      | (if (.positive | length) != 5 then "review needs exactly 5 positive test cases" else empty end),
        (if (.negative | length) != 3 then "review needs exactly 3 negative test cases" else empty end))
' "$openai")
while IFS= read -r problem; do
  [ -z "$problem" ] || fail "$openai: $problem"
done <<< "$problems"

[ "$status" -eq 0 ] && echo "manifests OK, version $version"
exit "$status"
