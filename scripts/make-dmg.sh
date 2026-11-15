#!/bin/bash
# Packs build/Utter.app into build/Utter.dmg with a shortcut to /Applications,
# so installing is: open the disk image, drag Utter onto Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Utter.app
[ -d "$APP" ] || { echo "Build the app first: scripts/build-app.sh" >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f build/Utter.dmg
hdiutil create -volname "Utter" -srcfolder "$STAGE" -ov -format UDZO build/Utter.dmg >/dev/null
echo "Built build/Utter.dmg ($(du -h build/Utter.dmg | cut -f1))"
