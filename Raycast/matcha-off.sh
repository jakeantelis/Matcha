#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Allow Sleep
# @raycast.packageName Matcha
# @raycast.icon 🍵
# @raycast.mode silent

CLI="/Applications/Matcha.app/Contents/Resources/matchactl"
if [ -x "$CLI" ]; then
  "$CLI" off
else
  matchactl off
fi
