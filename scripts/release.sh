#!/bin/bash
# Builds the app, packages it into dist/Music-Mixer-<VERSION>.dmg and
# publishes a GitHub release with notes taken from the CHANGELOG entry.
# Usage: scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Music Mixer"
VERSION=$(cat VERSION)
DMG="dist/Music-Mixer-$VERSION.dmg"

./scripts/build_app.sh

# Stage a drag-to-Applications DMG layout
STAGING="$(mktemp -d)/$APP_NAME"
mkdir -p "$STAGING"
cp -R "build/${APP_NAME}.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p dist
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"
rm -rf "$(dirname "$STAGING")"
echo "Created $DMG"

# Extract the CHANGELOG entry for this version as release notes
NOTES=$(awk -v ver="$VERSION" '
    /^## / { on = ($2 == ver) ; next }
    on { print }
' CHANGELOG.md)

gh release create "v$VERSION" "$DMG" \
    --title "Music Mixer $VERSION" \
    --notes "${NOTES:-Version $VERSION}"
echo "Release v$VERSION published."
