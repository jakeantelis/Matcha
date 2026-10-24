#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Toggle Keep-Awake
# @raycast.packageName Matcha
# @raycast.icon 🍵
# @raycast.mode silent

CLI="/Applications/Matcha.app/Contents/Resources/matchactl"
if [ -x "$CLI" ]; then
  "$CLI" toggle
else
  matchactl toggle
fi
