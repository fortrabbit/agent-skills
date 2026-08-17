#!/bin/sh
set -e

VERSION_URL="https://raw.githubusercontent.com/fortrabbit/agent-skills/main/VERSION"
INSTALL_URL="https://raw.githubusercontent.com/fortrabbit/agent-skills/main/install.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/.version"

LOCAL=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
REMOTE=$(curl -fsSL "$VERSION_URL" | tr -d '[:space:]')

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "fortrabbit agent-skills is up to date (v$LOCAL)."
  exit 0
fi

echo "Update available: v$LOCAL → v$REMOTE"

# Detect global vs project install from where this script lives
# (SCRIPT_DIR is <skills-base>/<skill>; its grandparent is ~/.claude, ~/.agents, or the project root)
SKILLS_PARENT="$(cd "$(dirname "$SCRIPT_DIR")/.." && pwd)"
if [ "$SKILLS_PARENT" = "$HOME/.claude" ] || [ "$SKILLS_PARENT" = "$HOME/.agents" ]; then
  FLAG=""
else
  FLAG="--project"
fi

curl -fsSL "$INSTALL_URL" | sh -s -- $FLAG

# Reset the update-check timer so we don't prompt again immediately
date +%s > "$SCRIPT_DIR/.last-update-check"
