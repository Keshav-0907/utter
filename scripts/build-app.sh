#!/bin/bash
# Builds build/Utter.app. Usage: scripts/build-app.sh [--run]
# Set UTTER_SIGN_IDENTITY to choose a signing identity; with none available the app is ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/Utter.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Utter "$APP/Contents/MacOS/Utter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
# Release builds pass their build number in (the CI run number).
if [ -n "${UTTER_BUILD_NUMBER:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $UTTER_BUILD_NUMBER" "$APP/Contents/Info.plist"
fi

# MLX looks for its compiled Metal shaders in a resource bundle with this exact name.
[ -f .build/metallib/mlx.metallib ] || scripts/build-metallib.sh
mkdir -p "$APP/Contents/Resources/mlx-swift_Cmlx.bundle"
cp .build/metallib/mlx.metallib "$APP/Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib"
# Resource bundles of the Swift packages we depend on.
for bundle in .build/release/*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
mkdir -p "$APP/Contents/Resources"
[ -f Resources/AppIcon.icns ] || swift scripts/make-icon.swift
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# A stable signing identity keeps macOS permission grants across rebuilds.
# Ad-hoc signing works too, but permissions must be re-granted after every build.
IDENTITY="${UTTER_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "Signed with: $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "Ad-hoc signed (no signing identity found)"
fi

echo "Built $APP"
if [ "${1:-}" = "--run" ]; then
    pkill -x Utter 2>/dev/null || true
    # Install where Spotlight and Launchpad can find it.
    rm -rf /Applications/Utter.app
    cp -R "$APP" /Applications/Utter.app
    open /Applications/Utter.app
fi
