#!/bin/sh
set -eu

# One-command installer for Matcha.
#
#   curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh
#   ... | sh -s -- --no-agents
#
# Downloads the latest release, verifies its SHA-256, installs to /Applications
# (or ~/Applications), opens it, and configures detected coding agents.

REPO="jakeantelis/Matcha"
LATEST="https://github.com/$REPO/releases/latest/download"
RAW_BASE="${MATCHA_RAW_BASE:-https://raw.githubusercontent.com/$REPO/main}"
AGENTS=1

for arg in "$@"; do
    case "$arg" in
        --no-agents) AGENTS=0 ;;
        --agents) AGENTS=1 ;;
        --help|-h)
            echo "Usage: install.sh [--no-agents]"
            echo "  --no-agents  install the app only, skip agent configuration"
            exit 0
            ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Matcha..."
curl -fsSL "$LATEST/Matcha.zip" -o "$TMP/Matcha.zip"
curl -fsSL "$LATEST/Matcha.zip.sha256" -o "$TMP/Matcha.zip.sha256"

EXPECTED=$(cut -d ' ' -f 1 "$TMP/Matcha.zip.sha256")
ACTUAL=$(shasum -a 256 "$TMP/Matcha.zip" | cut -d ' ' -f 1)
if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "error: checksum mismatch, download may be corrupt" >&2
    exit 1
fi

ditto -x -k "$TMP/Matcha.zip" "$TMP/unpacked"
APP="$TMP/unpacked/Matcha.app"
if [ ! -d "$APP" ] || [ ! -x "$APP/Contents/MacOS/Matcha" ]; then
    echo "error: release archive did not contain Matcha.app" >&2
    exit 1
fi

xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

DEST="/Applications"
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

if pgrep -x Matcha >/dev/null 2>&1; then
    echo "Closing the running copy..."
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

rm -rf "$DEST/Matcha.app"
ditto "$APP" "$DEST/Matcha.app"
xattr -dr com.apple.quarantine "$DEST/Matcha.app" 2>/dev/null || true

VERSION=$(defaults read "$DEST/Matcha.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
echo "Installed Matcha $VERSION at $DEST/Matcha.app"
open "$DEST/Matcha.app"

if [ "$AGENTS" = 1 ]; then
    echo
    SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || true)
    if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/install-agent-kit.sh" ] \
        && grep -q 'matcha-keep-awake' "$SELF_DIR/install-agent-kit.sh"; then
        AGENT_SCRIPT="$SELF_DIR/install-agent-kit.sh"
    else
        curl -fsSL "$RAW_BASE/Tools/install-agent-kit.sh" -o "$TMP/install-agent-kit.sh"
        AGENT_SCRIPT="$TMP/install-agent-kit.sh"
    fi
    sh "$AGENT_SCRIPT" || echo "warning: agent setup failed; run Tools/install-agent-kit.sh later" >&2
fi

echo
echo "Done. Matcha is running."
