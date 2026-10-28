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

OS=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
MAJOR=$(printf '%s' "$OS" | cut -d . -f 1)
if [ "$MAJOR" != "unknown" ] && [ "$MAJOR" -lt 11 ] 2>/dev/null; then
    echo "Matcha needs macOS 11 or newer. This Mac has $OS." >&2
    exit 1
fi

DEST="/Applications"
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

UPGRADE=0
if [ -d "$DEST/Matcha.app" ]; then
    UPGRADE=1
fi

WAS_ON=0
MATCHACTL="$DEST/Matcha.app/Contents/Resources/matchactl"
if [ -x "$MATCHACTL" ] && "$MATCHACTL" status 2>/dev/null | head -1 | grep -q '^on '; then
    WAS_ON=1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading the latest release..."
if ! curl -fsSL "$LATEST/Matcha.zip" -o "$TMP/Matcha.zip" \
    || ! curl -fsSL "$LATEST/Matcha.zip.sha256" -o "$TMP/Matcha.zip.sha256"; then
    echo "Couldn't download Matcha. Check your connection and try again." >&2
    echo "Releases: https://github.com/$REPO/releases" >&2
    exit 1
fi

EXPECTED=$(cut -d ' ' -f 1 "$TMP/Matcha.zip.sha256")
ACTUAL=$(shasum -a 256 "$TMP/Matcha.zip" | cut -d ' ' -f 1)
if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "The download was corrupt (checksum mismatch). Please try again." >&2
    exit 1
fi

ditto -x -k "$TMP/Matcha.zip" "$TMP/unpacked"
APP="$TMP/unpacked/Matcha.app"
if [ ! -d "$APP" ] || [ ! -x "$APP/Contents/MacOS/Matcha" ]; then
    echo "The release archive did not contain Matcha.app. Please try again." >&2
    exit 1
fi

if pgrep -x Matcha >/dev/null 2>&1; then
    if [ "$WAS_ON" = 1 ]; then
        echo "Closing Matcha; your session will resume when it reopens."
    else
        echo "Closing the running copy..."
    fi
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

VERSION=$(defaults read "$DEST/Matcha.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
if [ "$UPGRADE" = 1 ]; then
    echo "Updated Matcha to $VERSION."
else
    echo "Installed Matcha $VERSION."
fi
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
    sh "$AGENT_SCRIPT" || echo "Agent setup skipped; run Tools/install-agent-kit.sh later." >&2
fi

echo
echo "Done. Matcha is running."
if [ "$WAS_ON" = 1 ]; then
    echo "Your session resumed."
fi
echo "Start with the cup in the Dock, the menu bar, or Control-Option-Command-M."
