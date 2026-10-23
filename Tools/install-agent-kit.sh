#!/bin/sh
set -eu

# Configures every agent it can find with Matcha keep-awake instructions.
# Safe to run repeatedly; each edit is a managed, replaceable block.
#
#   curl -fsSL .../install-agent-kit.sh | sh
#   ... | sh -s -- --project     # also add Cursor/Aider rules to this repo
#
# Opt out of a target by removing its directory before running.

SKILL="matcha-keep-awake"
RAW_BASE="${MATCHA_AGENT_BASE:-https://raw.githubusercontent.com/jakeantelis/Matcha/main}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCAL_SKILL="$SCRIPT_DIR/../Agent/skills/$SKILL/SKILL.md"
LOCAL_SNIPPET="$SCRIPT_DIR/../Agent/instructions.md"

PROJECT=0
for arg in "$@"; do
    case "$arg" in
        --project) PROJECT=1 ;;
        --help|-h)
            echo "Usage: install-agent-kit.sh [--project]"
            echo "  --project  also write .cursor/rules and CONVENTIONS.md in the current directory"
            exit 0
            ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

SNIPPET="$TMP/instructions.md"
if [ -f "$LOCAL_SNIPPET" ]; then
    cp "$LOCAL_SNIPPET" "$SNIPPET"
else
    curl -fsSL "$RAW_BASE/Agent/instructions.md" -o "$SNIPPET"
fi

install_skill() {
    target="$1"
    mkdir -p "$target"
    if [ -f "$LOCAL_SKILL" ]; then
        cp "$LOCAL_SKILL" "$target/SKILL.md"
    else
        curl -fsSL "$RAW_BASE/Agent/skills/$SKILL/SKILL.md" -o "$target/SKILL.md"
    fi
    echo "skill    $target/SKILL.md"
}

append_block() {
    file="$1"
    mkdir -p "$(dirname "$file")"
    if [ -f "$file" ] && grep -q 'matcha-keep-awake:start' "$file" \
        && grep -q 'matcha-keep-awake:end' "$file"; then
        awk '
            /<!-- matcha-keep-awake:start -->/ { skip = 1 }
            skip && /<!-- matcha-keep-awake:end -->/ { skip = 0; next }
            !skip { print }
        ' "$file" > "$TMP/stripped"
        mv "$TMP/stripped" "$file"
        perl -0pi -e 's/\n+\z/\n/' "$file"
    fi
    if [ -s "$file" ]; then
        printf '\n' >> "$file"
    fi
    {
        printf '<!-- matcha-keep-awake:start -->\n'
        cat "$SNIPPET"
        printf '<!-- matcha-keep-awake:end -->\n'
    } >> "$file"
    echo "rules    $file"
}

install_skill "$HOME/.claude/skills/$SKILL"
install_skill "$HOME/.config/opencode/skills/$SKILL"

if [ -n "${AGENT_SKILLS_DIR:-}" ]; then
    install_skill "$AGENT_SKILLS_DIR/$SKILL"
fi

if [ -d "$HOME/.codex" ]; then
    append_block "$HOME/.codex/AGENTS.md"
fi

if [ -d "$HOME/.gemini" ]; then
    append_block "$HOME/.gemini/GEMINI.md"
fi

if [ -d "$HOME/.codeium/windsurf" ]; then
    append_block "$HOME/.codeium/windsurf/memories/global_rules.md"
fi

if [ "$PROJECT" = 1 ]; then
    RULE="$PWD/.cursor/rules/matcha-keep-awake.mdc"
    mkdir -p "$(dirname "$RULE")"
    {
        printf -- '---\n'
        printf 'description: Keep the Mac awake during long work with Matcha\n'
        printf 'alwaysApply: true\n'
        printf -- '---\n\n'
        cat "$SNIPPET"
    } > "$RULE"
    echo "rules    $RULE"
    append_block "$PWD/CONVENTIONS.md"
fi

echo
echo "Agent kit ready. Restart running agents to pick it up."
if [ "$PROJECT" = 0 ]; then
    echo "Cursor and Aider use project rules: rerun with --project inside a repo."
fi
if [ -f "$LOCAL_SNIPPET" ]; then
    SNIPPET_PATH=$(CDPATH= cd -- "$(dirname -- "$LOCAL_SNIPPET")" && pwd)/$(basename -- "$LOCAL_SNIPPET")
    echo "Other agents: paste $SNIPPET_PATH into their instructions."
else
    echo "Other agents: paste $RAW_BASE/Agent/instructions.md into their instructions."
fi
