#!/bin/sh
# Matcha status for xbar / BitBar
# Place in xbar plugins folder (or point xbar at the xbar/ directory).
# Refresh: every 10s

MATCHACTL="/Applications/Matcha.app/Contents/Resources/matchactl"
if [ ! -x "$MATCHACTL" ]; then
  echo "Matcha not installed"
  echo "---"
  echo "Install: curl -fsSL https://raw.githubusercontent.com/jakeantelis/Matcha/main/Tools/install.sh | sh"
  exit 0
fi

STATUS=$("$MATCHACTL" status 2>/dev/null)
ON=$(echo "$STATUS" | head -1 | grep -c '^on ')

if [ "$ON" = "1" ]; then
  REMAINING=$(echo "$STATUS" | grep -o 'remaining=[0-9]*' | cut -d= -f2)
  if [ -n "$REMAINING" ] && [ "$REMAINING" -ge 0 ]; then
    H=$((REMAINING / 3600))
    M=$(((REMAINING % 3600) / 60))
    S=$((REMAINING % 60))
    if [ "$H" -gt 0 ]; then
      echo "Matcha ${H}h${M}m | color=#2f9e44"
    else
      echo "Matcha ${M}:${S} | color=#2f9e44"
    fi
  else
    echo "Matcha ON | color=#2f9e44"
  fi
  echo "---"
  echo "Stop | shell=$MATCHACTL param1=off refresh=true terminal=false"
  echo "+15 min | shell=$MATCHACTL param1=extend param2=900 refresh=true terminal=false"
  echo "+30 min | shell=$MATCHACTL param1=extend param2=1800 refresh=true terminal=false"
  echo "+1 hour | shell=$MATCHACTL param1=extend param2=3600 refresh=true terminal=false"
else
  echo "Matcha OFF | color=#868e96"
  echo "---"
  echo "Start 1h | shell=$MATCHACTL param1=on param2=1h refresh=true terminal=false"
  echo "Start 2h | shell=$MATCHACTL param1=on param2=2h refresh=true terminal=false"
  echo "Start 4h | shell=$MATCHACTL param1=on param2=4h refresh=true terminal=false"
  echo "Start until stopped | shell=$MATCHACTL param1=on refresh=true terminal=false"
fi

echo "---"
echo "Settings... | shell=$MATCHACTL param1=status refresh=true terminal=false"
