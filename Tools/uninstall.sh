#!/bin/sh
set -eu

# Removes Matcha and the instructions it added to coding agents.
#
#   curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/uninstall.sh | sh
#   ... | sh -s -- --yes --purge
#
# --yes    do not ask for confirmation
# --purge  also remove preferences and saved session data

YES=0
PURGE=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) YES=1 ;;
        --purge) PURGE=1 ;;
        --help|-h)
            echo "Usage: uninstall.sh [--yes] [--purge]"
            echo "  --yes    do not ask for confirmation"
            echo "  --purge  also remove preferences and saved session data"
            exit 0
            ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [ "$YES" = 0 ]; then
    printf "Remove Matcha and its agent instructions? [y/N] " >&2
    answer=""
    read -r answer || true
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if pgrep -x Matcha >/dev/null 2>&1; then
    echo "Quitting Matcha..."
    pkill -x Matcha 2>/dev/null || true
    tries=0
    while pgrep -x Matcha >/dev/null 2>&1 && [ "$tries" -lt 30 ]; do
        sleep 0.1
        tries=$((tries + 1))
    done
    if pgrep -x Matcha >/dev/null 2>&1; then
        kill -9 "$(pgrep -x Matcha)" 2>/dev/null || true
        sleep 0.5
    fi
fi

if [ -n "${MATCHA_APP_DIR:-}" ]; then
    APPS="$MATCHA_APP_DIR"
else
    APPS="/Applications $HOME/Applications"
fi

for dir in $APPS; do
    if [ -d "$dir/Matcha.app" ]; then
        rm -rf "$dir/Matcha.app"
        echo "Removed $dir/Matcha.app"
    fi
done

remove_block() {
    file="$1"
    [ -f "$file" ] || return 0
    grep -q 'matcha-keep-awake:start' "$file" || return 0
    grep -q 'matcha-keep-awake:end' "$file" || return 0
    awk '
        /<!-- matcha-keep-awake:start -->/ { skip = 1 }
        skip && /<!-- matcha-keep-awake:end -->/ { skip = 0; next }
        !skip { print }
    ' "$file" > "$TMP/stripped"
    mv "$TMP/stripped" "$file"
    perl -0pi -e 's/\n+\z/\n/' "$file"
    if [ -s "$file" ]; then
        echo "Removed Matcha rules from $file"
    else
        rm -f "$file"
        echo "Removed $file"
    fi
}

remove_block "$HOME/.codex/AGENTS.md"
remove_block "$HOME/.gemini/GEMINI.md"
remove_block "$HOME/.codeium/windsurf/memories/global_rules.md"

for dir in "$HOME/.claude/skills/matcha-keep-awake" \
    "$HOME/.config/opencode/skills/matcha-keep-awake" \
    "${AGENT_SKILLS_DIR:-/nonexistent}/matcha-keep-awake"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "Removed $dir"
    fi
done

rm -rf "$HOME/Library/Application Support/Matcha"

if [ "$PURGE" = 1 ]; then
    defaults delete com.matcha.app 2>/dev/null || true
    echo "Removed preferences and saved session data."
fi

echo
echo "Matcha is uninstalled."
echo "Cursor/Aider project rules are left in place; delete .cursor/rules/matcha-keep-awake.mdc"
echo "and the Matcha block in CONVENTIONS.md inside any repo where you added them."
if [ "$PURGE" = 0 ]; then
    echo "Preferences were kept. Run again with --purge to remove them."
fi
echo "If Matcha was set to launch at login, confirm it is gone in System Settings > General > Login Items."
