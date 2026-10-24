#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Matcha Status
# @raycast.packageName Matcha
# @raycast.icon 🍵
# @raycast.mode compact

CLI="/Applications/Matcha.app/Contents/Resources/matchactl"
if [ -x "$CLI" ]; then
  "$CLI" status
else
  matchactl status
fi
