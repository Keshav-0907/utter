#!/bin/bash
# Packs build/Utter.app into build/Utter.dmg: a styled installer window with the app,
# an arrow, and a shortcut to /Applications. Uses dmgbuild, which writes the window
# layout directly and so works on a build server with nobody logged in.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Utter.app
[ -d "$APP" ] || { echo "Build the app first: scripts/build-app.sh" >&2; exit 1; }
[ -f Resources/dmg-background.tiff ] || swift scripts/make-dmg-background.swift

VENV=.build/dmg-venv
if [ ! -x "$VENV/bin/dmgbuild" ]; then
    # The system Python is the dependable one for creating a virtual environment.
    PYTHON=/usr/bin/python3
    [ -x "$PYTHON" ] || PYTHON=python3
    rm -rf "$VENV"
    "$PYTHON" -m venv "$VENV"
    "$VENV/bin/pip" install --quiet dmgbuild
fi

rm -f build/Utter.dmg
"$VENV/bin/dmgbuild" -s scripts/dmg-settings.py -D app="$APP" "Utter" build/Utter.dmg >/dev/null
echo "Built build/Utter.dmg ($(du -h build/Utter.dmg | cut -f1))"
