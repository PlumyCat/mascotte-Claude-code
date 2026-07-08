#!/usr/bin/env bash
# Builds MascotteApp in release mode and assembles it into a self-contained
# dist/Mascotte.app bundle (binary + Info.plist + Resources), ad-hoc signed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Mascotte"
BUNDLE_ID="fr.ericfer.mascotte"
EXECUTABLE_NAME="MascotteApp"
DIST_DIR="$REPO_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PET_DIR="$REPO_ROOT/pets/casquette"

echo "==> swift build -c release"
swift build -c release

BUILT_BINARY="$REPO_ROOT/.build/release/$EXECUTABLE_NAME"
if [ ! -f "$BUILT_BINARY" ]; then
    echo "error: built binary not found at $BUILT_BINARY" >&2
    exit 1
fi

echo "==> assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILT_BINARY" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$PET_DIR/spritesheet.webp" "$RESOURCES_DIR/spritesheet.webp"
cp "$PET_DIR/pet.json" "$RESOURCES_DIR/pet.json"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
codesign -s - --force --deep "$APP_BUNDLE"

echo "==> done: $APP_BUNDLE"
