#!/bin/bash
# Spellbrawl launcher (macOS): double-click in Finder to open the game in its own app window.
DIR="$(cd "$(dirname "$0")" && pwd)"
URL="file://${DIR// /%20}/index.html"
if [ -d "/Applications/Google Chrome.app" ]; then
  open -na "Google Chrome" --args --app="$URL" --window-size=1600,1000
elif [ -d "/Applications/Microsoft Edge.app" ]; then
  open -na "Microsoft Edge" --args --app="$URL" --window-size=1600,1000
else
  open "$DIR/index.html"
fi
