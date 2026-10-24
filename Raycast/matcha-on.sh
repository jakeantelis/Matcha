#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Keep Awake (Custom/Preset)
# @raycast.packageName Matcha
# @raycast.icon 🍵
# @raycast.mode silent
# @raycast.argument1 { "type": "text", "placeholder": "Duration (e.g. 2h, 90m, or blank)", "optional": true }

CLI="/Applications/Matcha.app/Contents/Resources/matchactl"
if [ -n "$1" ]; then
  if [ -x "$CLI" ]; then "$CLI" on "$1"; else matchactl on "$1"; fi
else
  if [ -x "$CLI" ]; then "$CLI" on; else matchactl on; fi
fi
