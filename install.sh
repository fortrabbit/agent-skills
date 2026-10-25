#!/bin/sh
# Kept only because update.sh from 1.x installs downloads this file. 2.x installs through the
# frbit CLI, gh skill or npx skills; this script installs nothing.
cat >&2 <<'EOF'
fortrabbit agent skills 2.x no longer install with this script.

Update with the fortrabbit CLI (1.7.0 or later), which also removes the 1.x files:

  frbit skills update            # add --project for skills installed in a project

Or with the GitHub CLI, then delete the 1.x leftovers:

  gh skill install fortrabbit/agent-skills fortrabbit --agent claude-code --scope user
  rm -rf ~/.claude/skills/fortrabbit-api-access ~/.agents/skills/fortrabbit-api-access

More: https://github.com/fortrabbit/agent-skills#upgrading-from-1x
EOF
exit 1
