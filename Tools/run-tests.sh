#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swiftc -O Tests/main.swift Sources/Support.swift \
    -framework AppKit -framework IOKit \
    -o /tmp/matcha-tests
/tmp/matcha-tests