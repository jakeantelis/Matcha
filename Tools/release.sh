#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Matcha.app
TMP=build/universal
DIST=dist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

DEV_ID="Developer ID Application: Jake Antelis"
NOTARY_PROFILE="matcha"

rm -rf "$APP" "$TMP"
mkdir -p "$TMP/arm64" "$TMP/x86_64" "$APP/Contents/MacOS" "$APP/Contents/Resources"

FLAGS=(
    -O
    -framework AppKit
    -framework Carbon
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

# ---- Signing ----
SIGNED=false
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$DEV_ID"; then
    echo "Signing with $DEV_ID (hardened runtime + timestamp)..."
    if codesign --force --options runtime --timestamp --sign "$DEV_ID" "$APP" 2>&1; then
        codesign --verify --deep --strict "$APP"
        SIGNED=true
    fi
fi
if [[ "$SIGNED" != true ]]; then
    echo "warning: no Developer ID identity found, falling back to ad-hoc signature" >&2
    if ! codesign --force --sign - "$APP" 2>&1; then
        echo "warning: ad-hoc codesign failed, continuing unsigned" >&2
    fi
fi

ARCHS=$(lipo -archs "$APP/Contents/MacOS/Matcha")
echo "Universal binary: $ARCHS"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
    echo "ERROR: expected both arm64 and x86_64 in $ARCHS" >&2
    exit 1
fi

# ---- Notarization ----
NOTARIZED=false
if [[ "$SIGNED" == true ]] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    mkdir -p "$DIST"
    rm -f "$DIST/Matcha-notary.zip"
    ditto -c -k --norsrc --noextattr --keepParent "$APP" "$DIST/Matcha-notary.zip"
    echo "Submitting to Apple notary service..."
    xcrun notarytool submit "$DIST/Matcha-notary.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$DIST/Matcha-notary.zip"
    xcrun stapler staple "$APP"
    NOTARIZED=true
    echo "Notarized and stapled."
else
    echo "note: notarization skipped (needs Developer ID + keychain profile '$NOTARY_PROFILE')"
fi

mkdir -p "$DIST"
rm -f "$DIST/Matcha.zip" "$DIST/Matcha.zip.sha256"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$DIST/Matcha.zip"
(cd "$DIST" && shasum -a 256 Matcha.zip > Matcha.zip.sha256)
echo "Packaged $DIST/Matcha.zip ($VERSION) signed=$SIGNED notarized=$NOTARIZED"
cat "$DIST/Matcha.zip.sha256"

if [[ "${1:-}" == "--publish" ]]; then
    gh release create "v$VERSION" \
        "$DIST/Matcha.zip" \
        "$DIST/Matcha.zip.sha256" \
        --title "Matcha $VERSION" \
        --notes-file RELEASE_NOTES.md
fi