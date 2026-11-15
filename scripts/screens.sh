#!/usr/bin/env bash
# Usage: screens.sh <path/to/SayLess.app> <outdir>
# Boots an iPhone simulator, launches the app in demo mode on each screen
# (launch args: -SLDemo YES -SLScreen <name>) and saves PNG screenshots.
set -uo pipefail
APP="$1"; OUT="$2"; mkdir -p "$OUT"
BUNDLE=com.knightabdo.sayless
SCREENS=(${SHOT_SCREENS:-home})
UDID=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
c=[x for k,v in d.items() if 'iOS' in k for x in v if 'Pro Max' in x['name']]
c.sort(key=lambda x:x['name']); print(c[-1]['udid'] if c else '')")
[ -z "$UDID" ] && { echo "no simulator"; exit 0; }
# Software keyboard on, so the typing screen shows the real keyboard over the app.
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false 2>/dev/null
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2>/dev/null
xcrun simctl install "$UDID" "$APP"
for appearance in light dark; do
  xcrun simctl ui "$UDID" appearance $appearance
  for s in "${SCREENS[@]}"; do
    xcrun simctl terminate "$UDID" $BUNDLE 2>/dev/null
    xcrun simctl launch "$UDID" $BUNDLE -SLDemo YES -SLScreen "$s" >/dev/null
    sleep 6
    xcrun simctl io "$UDID" screenshot "$OUT/$s-$appearance.png" >/dev/null 2>&1 && echo "shot $s-$appearance"
  done
done
