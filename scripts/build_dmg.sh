#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/Loquor.app"
DMG_NAME="Loquor.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
STAGING_DIR="$DIST_DIR/dmg-staging"
TEMP_DMG_PATH="$DIST_DIR/Loquor-temp.dmg"
VOLUME_NAME="Loquor Installer"

"$ROOT_DIR/scripts/build_native_app.sh"

echo "Preparing DMG staging directory..."
rm -rf "$STAGING_DIR" "$TEMP_DMG_PATH" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

ditto "$APP_PATH" "$STAGING_DIR/Loquor.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [ -f "$APP_PATH/Contents/Resources/Loquor.icns" ]; then
  cp "$APP_PATH/Contents/Resources/Loquor.icns" "$STAGING_DIR/.VolumeIcon.icns"
fi

echo "Creating temporary DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  "$TEMP_DMG_PATH" \
  >/dev/null

DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG_PATH" | awk '/Apple_HFS/ {print $1; exit}')"
if [ -z "$DEVICE" ]; then
  echo "Failed to attach temporary DMG." >&2
  exit 1
fi

VOLUME_PATH="/Volumes/$VOLUME_NAME"

if [ -f "$VOLUME_PATH/.VolumeIcon.icns" ]; then
  SetFile -a C "$VOLUME_PATH" || true
fi

sync
hdiutil detach "$DEVICE" >/dev/null

echo "Converting DMG to compressed image..."
hdiutil convert "$TEMP_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$TEMP_DMG_PATH"
rm -rf "$STAGING_DIR"

echo "DMG created at: $DMG_PATH"
