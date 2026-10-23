#!/bin/sh
set -eu

# Installs the Matcha keep-awake skill for Claude Code and opencode.
# Other agents can use the snippet in Agent/AGENTS.md.
# Safe to run repeatedly.

SKILL="matcha-keep-awake"
RAW_BASE="${MATCHA_AGENT_BASE:-https://raw.githubusercontent.com/jakeantelis/Matcha/main}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCAL_SKILL="$SCRIPT_DIR/../Agent/skills/$SKILL/SKILL.md"

TARGETS="$HOME/.claude/skills/$SKILL $HOME/.config/opencode/skills/$SKILL"

if [ -n "${AGENT_SKILLS_DIR:-}" ]; then
    TARGETS="$TARGETS $AGENT_SKILLS_DIR/$SKILL"
fi

for target in $TARGETS; do
    mkdir -p "$target"
    if [ -f "$LOCAL_SKILL" ]; then
        cp "$LOCAL_SKILL" "$target/SKILL.md"
    else
        curl -fsSL "$RAW_BASE/Agent/skills/$SKILL/SKILL.md" -o "$target/SKILL.md"
    fi
    echo "installed $target/SKILL.md"
done

echo
echo "Restart Claude Code or opencode to pick up the skill."
echo "It will call matchactl before long builds and stop the session afterwards."
echo
echo "Using Codex CLI, Gemini CLI, Cursor, Windsurf, Aider, Zed, or another agent?"
echo "Copy the snippet from:"
if [ -f "$SCRIPT_DIR/../Agent/AGENTS.md" ]; then
    echo "  $SCRIPT_DIR/../Agent/AGENTS.md"
else
    echo "  $RAW_BASE/Agent/AGENTS.md"
fi
