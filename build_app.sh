#!/bin/bash
# Builds SpotifyWidget.app from the Swift package.
# Requirement: Xcode or Xcode Command Line Tools (swift build must work).

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Compiling (Release)..."
swift build -c release

APP="SpotifyWidget.app"
BIN=".build/release/SpotifyWidget"
INSTALL_DIR="/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP"

echo "==> Building app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SpotifyWidget"
cp Info.plist "$APP/Contents/Info.plist"

echo "==> Signing (ad hoc)..."
codesign --force --deep --sign - "$APP"

echo "==> Installing to $INSTALL_DIR (needed so autostart-at-login keeps working) ..."
rm -rf "$INSTALLED_APP"
cp -R "$APP" "$INSTALL_DIR/"

echo ""
echo "Done! Start with:  open \"$INSTALLED_APP\""
echo "   On first launch, macOS will ask for permission to control Spotify -> allow it."
echo "   (If the prompt doesn't appear: System Settings -> Privacy & Security -> Automation)"
echo "   The widget registers itself to start at login automatically on first launch."
echo "   You can toggle this any time via right-click on the widget."
echo "   (Also check: System Settings -> General -> Login Items)"
