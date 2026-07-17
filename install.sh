#!/bin/sh
set -e

# Detect native Windows (CMD/PowerShell) — uname returns empty in those shells
case "$(uname -s 2>/dev/null)" in
  Linux|Darwin|FreeBSD|MINGW*|CYGWIN*|MSYS*) ;;
  '')
    echo "Error: This script requires a POSIX shell. On Windows, run it inside WSL or Git Bash."
    exit 1
    ;;
esac

REPO_URL="https://github.com/fortrabbit/agent-skills/archive/refs/heads/main.tar.gz"
LOCAL=false

for arg in "$@"; do
  case $arg in
    --project|-p) LOCAL=true ;;
  esac
done

# Skills shipped by this package (each is a directory under skills/)
SKILLS="fortrabbit fortrabbit-api-tokens"

HAS_CLAUDE=false
HAS_CODEX=false

if $LOCAL; then
  CLAUDE_BASE=".claude/skills"
  CODEX_BASE=".agents/skills"
  SCOPE="project"
else
  CLAUDE_BASE="$HOME/.claude/skills"
  CODEX_BASE="$HOME/.agents/skills"
  SCOPE="global"

  # For global installs, only target tools that are actually installed
  [ -d "$HOME/.claude" ] && HAS_CLAUDE=true
  [ -d "$HOME/.agents" ] && HAS_CODEX=true

  if ! $HAS_CLAUDE && ! $HAS_CODEX; then
    echo "Error: Neither Claude Code (~/.claude) nor OpenAI Codex (~/.agents) appears to be installed."
    echo "Install one of those tools first, or use --local to install per-project."
    exit 1
  fi
fi

echo "Installing fortrabbit agent-skills ($SCOPE)..."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$REPO_URL" | tar xz -C "$TMP" --strip-components=1

# Install every skill in $SKILLS into the given skills base directory
install_skills() {
  BASE="$1"
  for SKILL in $SKILLS; do
    DIR="$BASE/$SKILL"
    mkdir -p "$DIR"
    cp -r "$TMP/skills/$SKILL/." "$DIR/"
    cp "$TMP/VERSION" "$DIR/.version"
    cp "$TMP/update.sh" "$DIR/update.sh"
    cp "$TMP/uninstall.sh" "$DIR/uninstall.sh"
    chmod +x "$DIR/update.sh" "$DIR/uninstall.sh"
    date +%s > "$DIR/.last-update-check"
    echo "    $DIR"
  done
}

# Claude Code
if $LOCAL || $HAS_CLAUDE; then
  echo "  Claude Code:"
  install_skills "$CLAUDE_BASE"
fi

# OpenAI Codex
if $LOCAL || $HAS_CODEX; then
  echo "  Codex:"
  install_skills "$CODEX_BASE"
fi

# GitHub Copilot (per-project only — instructions are repo-scoped)
if $LOCAL; then
  mkdir -p ".github/instructions"
  cp "$TMP/.github/instructions/fortrabbit.instructions.md" ".github/instructions/"
  echo "  Copilot      →  .github/instructions/fortrabbit.instructions.md"
fi

echo ""
echo "Done. Use /fortrabbit with your agent to get started."
