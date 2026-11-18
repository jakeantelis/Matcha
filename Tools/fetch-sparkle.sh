#!/bin/zsh
# Downloads the pinned Sparkle release (MIT) into .build-tools/ once, checks its SHA-256, and prints the folder.
# Sparkle runs update checks. It is downloaded at build time and never committed to the repo.
set -euo pipefail
cd "$(dirname "$0")/.."

SPARKLE_VERSION=2.10.1
SPARKLE_SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
DIR=.build-tools/sparkle-$SPARKLE_VERSION

if [[ ! -d "$DIR/Sparkle.framework" ]]; then
    rm -rf "$DIR" "$DIR.download"
    mkdir -p "$DIR.download"
    curl -fsSL -o "$DIR.download/Sparkle.tar.xz" \
        "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" >&2
    echo "$SPARKLE_SHA256  $DIR.download/Sparkle.tar.xz" | shasum -a 256 -c - >&2
    mkdir -p "$DIR"
    tar -xJf "$DIR.download/Sparkle.tar.xz" -C "$DIR"
    rm -rf "$DIR.download"
fi
echo "$PWD/$DIR"
