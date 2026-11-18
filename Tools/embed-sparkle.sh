#!/bin/zsh
# Copies Sparkle.framework into the app and signs its parts from the inside out.
# Usage: embed-sparkle.sh <sparkle folder> <Matcha.app> <signing identity, or - for ad hoc>
# Matcha is not sandboxed, so Sparkle's XPC services are left out, as Sparkle's documentation allows.
set -euo pipefail
SPARKLE=$1 APP=$2 ID=$3
FW="$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$FW"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.framework" "$FW"   # ditto keeps the Versions symlinks
rm -rf "$FW/Versions/B/XPCServices" "$FW/XPCServices"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
if [[ "$ID" == "-" ]]; then
    SIGN=(codesign --force --sign -)
else
    SIGN=(codesign --force --options runtime --timestamp --sign "$ID")
fi
"${SIGN[@]}" "$FW/Versions/B/Autoupdate"
"${SIGN[@]}" "$FW/Versions/B/Updater.app"
"${SIGN[@]}" "$FW"
