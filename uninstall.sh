#!/bin/sh
set -e

# Skills shipped by this package (each is a directory under skills/)
SKILLS="fortrabbit fortrabbit-api-tokens"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_BASE="$(dirname "$SCRIPT_DIR")"   # e.g. ~/.claude/skills or <project>/.claude/skills

if [ "$SKILLS_BASE" = "$HOME/.claude/skills" ] || [ "$SKILLS_BASE" = "$HOME/.agents/skills" ]; then
  CLAUDE_BASE="$HOME/.claude/skills"
  CODEX_BASE="$HOME/.agents/skills"
  COPILOT_FILE=""
  SCOPE="global"
else
  PROJECT_ROOT="$(cd "$SKILLS_BASE/.." && pwd)"
  PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
  CLAUDE_BASE="$PROJECT_ROOT/.claude/skills"
  CODEX_BASE="$PROJECT_ROOT/.agents/skills"
  COPILOT_FILE="$PROJECT_ROOT/.github/instructions/fortrabbit.instructions.md"
  SCOPE="project"
fi

echo "This will remove fortrabbit agent-skills ($SCOPE install):"
for SKILL in $SKILLS; do
  [ -d "$CLAUDE_BASE/$SKILL" ] && echo "  $CLAUDE_BASE/$SKILL"
  [ -d "$CODEX_BASE/$SKILL" ]  && echo "  $CODEX_BASE/$SKILL"
done
[ -n "$COPILOT_FILE" ] && [ -f "$COPILOT_FILE" ] && echo "  $COPILOT_FILE"
echo ""
printf "Continue? [y/N] "
read -r CONFIRM
case "$CONFIRM" in
  [yY]) ;;
  *) echo "Aborted."; exit 0 ;;
esac

for SKILL in $SKILLS; do
  [ -d "$CLAUDE_BASE/$SKILL" ] && rm -rf "$CLAUDE_BASE/$SKILL" && echo "Removed $CLAUDE_BASE/$SKILL"
  [ -d "$CODEX_BASE/$SKILL" ]  && rm -rf "$CODEX_BASE/$SKILL"  && echo "Removed $CODEX_BASE/$SKILL"
done
[ -n "$COPILOT_FILE" ] && [ -f "$COPILOT_FILE" ] && rm "$COPILOT_FILE" && echo "Removed $COPILOT_FILE"

echo ""
echo "fortrabbit agent-skills uninstalled."
