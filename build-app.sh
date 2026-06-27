#!/bin/sh
set -eu

swift build -c release

APP_DIR=".build/release/ClipKey.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
GENERATED_ICONS_DIR=".build/generated-icons"

swift Tools/generate-icons.swift "$GENERATED_ICONS_DIR"
iconutil -c icns "$GENERATED_ICONS_DIR/ClipKeyIcon.iconset" -o "$GENERATED_ICONS_DIR/ClipKeyIcon.icns"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/release/ClipKey" "$MACOS_DIR/ClipKey"
cp "$GENERATED_ICONS_DIR/ClipKeyIcon.icns" "$RESOURCES_DIR/ClipKeyIcon.icns"
cp "$GENERATED_ICONS_DIR/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>ClipKey</string>
  <key>CFBundleIdentifier</key>
  <string>local.clipkey</string>
  <key>CFBundleName</key>
  <string>ClipKey</string>
  <key>CFBundleDisplayName</key>
  <string>ClipKey</string>
  <key>CFBundleIconFile</key>
  <string>ClipKeyIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
