#!/bin/bash
# Builds Glyph in release mode and packages it as a proper .app bundle.
# A real bundle (with a Info.plist + bundle identifier) is required for
# LSUIElement, LaunchAtLogin, and UNUserNotificationCenter to work correctly —
# a raw command-line binary from `swift build` alone cannot host these.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Glyph"
APP_DIR="${APP_NAME}.app"
BIN_PATH=".build/release/${APP_NAME}"

echo "Building ${APP_NAME} (release)..."
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Prefer a real "Apple Development" identity (created automatically by Xcode
# once signed into an Apple ID) over ad-hoc signing. TCC ties permissions
# like Screen Recording to the signing certificate's identity — ad-hoc
# signatures have none, so every rebuild changes the binary's hash and macOS
# treats it as a brand-new, unauthorized app, re-prompting every time.
# A real (even free) identity keeps that grant stable across rebuilds.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 "Apple Development" | sed -E 's/.*"(.*)"/\1/')

if [ -z "$IDENTITY" ]; then
    IDENTITY="-"
    echo "No 'Apple Development' signing identity found — signing ad-hoc."
    echo "Screen Recording permission will need to be re-granted after every rebuild."
    echo "To fix: open Xcode -> Settings -> Accounts, sign in with your Apple ID, then re-run this script."
else
    echo "Signing with identity: $IDENTITY"
fi

codesign --force --deep --options runtime --sign "$IDENTITY" "$APP_DIR"

echo "Built ${APP_DIR}"
echo "Move it to /Applications and launch it to grant Screen Recording permission when prompted."
