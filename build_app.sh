#!/bin/bash
# Builds SpotifyWidget.app from the Swift package.
# Requirement: Xcode or Xcode Command Line Tools (swift build must work).

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Compiling (Release)..."
swift build -c release

APP="SpotifyWidget.app"
BIN=".build/release/SpotifyWidget"

echo "==> Building app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SpotifyWidget"
cp Info.plist "$APP/Contents/Info.plist"

echo "==> Signing (ad hoc)..."
codesign --force --deep --sign - "$APP"

echo ""
echo "Done! Start with:  open $APP"
echo "   On first launch, macOS will ask for permission to control Spotify -> allow it."
echo "   (If the prompt doesn't appear: System Settings -> Privacy & Security -> Automation)"
