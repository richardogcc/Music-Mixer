#!/bin/bash
# Builds Music Mixer.app into build/ from a release swift build.
# Injects the version from VERSION into Info.plist and copies the app icon.
set -euo pipefail
cd "$(dirname "$0")/.."

PRODUCT="MusicMixer"
APP_NAME="Music Mixer"
VERSION=$(cat VERSION)

swift build -c release

APP="build/${APP_NAME}.app"
BIN=".build/release/${PRODUCT}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$PRODUCT"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

if [ ! -f Resources/AppIcon.icns ]; then
    echo "Resources/AppIcon.icns not found — regenerating with scripts/make_icon.swift..."
    swift scripts/make_icon.swift
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc code signing with sandbox disabled (required for CoreAudio process taps)
ENTITLEMENTS="$(mktemp -t MusicMixer-entitlements).plist"
cat > "$ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
EOF
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"
rm -f "$ENTITLEMENTS"

echo "Built $APP (v$VERSION)"
