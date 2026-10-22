#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Matcha.app
DIST=dist
mode="${1:-build}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

echo "Compiling..."
swiftc -O Sources/*.swift \
    -o "$APP/Contents/MacOS/Matcha" \
    -framework AppKit \
    -framework IOKit \
    -framework ServiceManagement \
    -framework UserNotifications

mkdir -p "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
if [[ -f Tools/matchactl ]]; then
    cp Tools/matchactl "$APP/Contents/Resources/matchactl"
    chmod +x "$APP/Contents/Resources/matchactl"
fi
if ! codesign --force --sign - "$APP" 2>&1; then
    echo "warning: codesign failed, continuing (ad-hoc signature)" >&2
fi
date "+%Y-%m-%d %H:%M:%S" > "$APP/Contents/Resources/BUILD_STAMP"
echo "Built $APP"

if [[ "$mode" == "package" || "$mode" == "install" ]]; then
    mkdir -p "$DIST"
    rm -f "$DIST/Matcha.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Matcha.zip"
    echo "Packaged $DIST/Matcha.zip"
fi

if [[ "$mode" == "install" ]]; then
    if [[ -w /Applications ]]; then
        DEST="/Applications/Matcha.app"
    else
        DEST="$HOME/Applications/Matcha.app"
        mkdir -p "$HOME/Applications"
    fi
    pkill -x Matcha 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
    ditto "$APP" "$DEST"
    if ! cmp -s "$APP/Contents/MacOS/Matcha" "$DEST/Contents/MacOS/Matcha"; then
        echo "ERROR: installed binary does not match build!" >&2
        exit 1
    fi
    echo "Installed $DEST (build $(cat "$DEST/Contents/Resources/BUILD_STAMP"))"
fi
