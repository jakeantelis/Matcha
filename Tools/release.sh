#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Matcha.app
TMP=build/universal
DIST=dist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

DEV_ID="D430FCAFBA0DBC0F48D765E55C07BF3BA1FCEF85"
NOTARY_PROFILE="jake-antelis"

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
        if codesign -dv --verbose=2 "$APP" 2>&1 | grep "Authority=Developer ID Certification Authority" >/dev/null; then
            codesign --verify --deep --strict "$APP"
            SIGNED=true
        else
            echo "warning: signing identity is not Apple-issued; Developer ID Certification Authority is missing" >&2
        fi
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

# ---- DMG (friendly drag-to-Applications installer) ----
DMG="$DIST/Matcha.dmg"
DMG_NOTARIZED=false
DMG_STAGE=build/dmg
rm -f "$DMG" "$DMG.sha256"
DMGBUILD="${DMGBUILD:-$(ls .build-tools/bin/dmgbuild 2>/dev/null || command -v dmgbuild || true)}"
if [[ -n "$DMGBUILD" ]] && "$DMGBUILD" -s Tools/dmg/settings.py -D here="$PWD/Tools/dmg" -D app="$APP" -D icon=Resources/AppIcon.icns "Matcha" "$DMG" >/dev/null 2>&1 \
   && hdiutil verify "$DMG" >/dev/null 2>&1; then
    echo "DMG built with the polished window."
else
    echo "note: using the plain disk image (dmgbuild unavailable or its image did not verify)"
    rm -f "$DMG"
    rm -rf "$DMG_STAGE"
    mkdir -p "$DMG_STAGE"
    cp -R "$APP" "$DMG_STAGE/Matcha.app"
    ln -s /Applications "$DMG_STAGE/Applications"
    hdiutil create -volname "Matcha" -srcfolder "$DMG_STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
    rm -rf "$DMG_STAGE"
fi

if [[ "$SIGNED" == true ]]; then
    codesign --force --timestamp --sign "$DEV_ID" "$DMG"
fi
if [[ "$NOTARIZED" == true ]]; then
    echo "Notarizing DMG..."
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    DMG_NOTARIZED=true
    echo "DMG notarized and stapled."
else
    echo "note: DMG notarization skipped (app not notarized)"
fi
(cd "$DIST" && shasum -a 256 Matcha.dmg > Matcha.dmg.sha256)
echo "Packaged $DMG ($VERSION) signed=$SIGNED notarized=$DMG_NOTARIZED"
cat "$DIST/Matcha.dmg.sha256"

if [[ "${1:-}" == "--publish" ]]; then
    if [[ "$SIGNED" != true || "$NOTARIZED" != true || "$DMG_NOTARIZED" != true ]]; then
        echo "ERROR: refusing to publish without Apple Developer ID signing and notarization" >&2
        exit 1
    fi
    spctl -a -vv "$APP"
    gh release create "v$VERSION" \
        "$DIST/Matcha.zip" \
        "$DIST/Matcha.zip.sha256" \
        "$DIST/Matcha.dmg" \
        "$DIST/Matcha.dmg.sha256" \
        --title "Matcha $VERSION" \
        --notes-file RELEASE_NOTES.md
fi