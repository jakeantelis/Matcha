#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Matcha.app
TMP=build/universal
DIST=dist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

rm -rf "$APP" "$TMP"
mkdir -p "$TMP/arm64" "$TMP/x86_64" "$APP/Contents/MacOS" "$APP/Contents/Resources"

FLAGS=(
    -O
    -framework AppKit
    -framework IOKit
    -framework ServiceManagement
    -framework UserNotifications
)

echo "Compiling arm64..."
swiftc Sources/*.swift -target arm64-apple-macos11.0 "${FLAGS[@]}" -o "$TMP/arm64/Matcha"

echo "Compiling x86_64..."
swiftc Sources/*.swift -target x86_64-apple-macos11.0 "${FLAGS[@]}" -o "$TMP/x86_64/Matcha"

lipo -create "$TMP/arm64/Matcha" "$TMP/x86_64/Matcha" -output "$APP/Contents/MacOS/Matcha"

cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
cp Tools/matchactl "$APP/Contents/Resources/matchactl"
chmod +x "$APP/Contents/Resources/matchactl"
date "+%Y-%m-%d %H:%M:%S" > "$APP/Contents/Resources/BUILD_STAMP"

if ! codesign --force --sign - "$APP" 2>&1; then
    echo "warning: codesign failed, continuing (ad-hoc signature)" >&2
fi

ARCHS=$(lipo -archs "$APP/Contents/MacOS/Matcha")
echo "Universal binary: $ARCHS"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
    echo "ERROR: expected both arm64 and x86_64 in $ARCHS" >&2
    exit 1
fi

mkdir -p "$DIST"
rm -f "$DIST/Matcha.zip" "$DIST/Matcha.zip.sha256"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$DIST/Matcha.zip"
(cd "$DIST" && shasum -a 256 Matcha.zip > Matcha.zip.sha256)
echo "Packaged $DIST/Matcha.zip ($VERSION)"
cat "$DIST/Matcha.zip.sha256"

if [[ "${1:-}" == "--publish" ]]; then
    gh release create "v$VERSION" \
        "$DIST/Matcha.zip" \
        "$DIST/Matcha.zip.sha256" \
        --title "Matcha $VERSION" \
        --notes-file RELEASE_NOTES.md
fi
