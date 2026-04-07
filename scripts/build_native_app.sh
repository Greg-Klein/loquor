#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE_DIR="$ROOT_DIR/NativeMacApp"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Loquor.app"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BACKEND_RUNTIME_DIR="$RESOURCES_DIR/backend-runtime"
ASSETS_DIR="$NATIVE_DIR/Assets"
ICON_SOURCE="$ASSETS_DIR/LoquorIcon.png"
ICONSET_DIR="$DIST_DIR/Loquor.iconset"
ICNS_PATH="$RESOURCES_DIR/Loquor.icns"

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"

if [ ! -f "$ICON_SOURCE" ]; then
  echo "Generating app icon source..."
  swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$ICON_SOURCE"
fi

echo "Building Swift app in release mode..."
swift build -c release --package-path "$NATIVE_DIR"

BIN_PATH="$(swift build -c release --package-path "$NATIVE_DIR" --show-bin-path)/SpeechToTextNative"

echo "Building standalone backend runtime..."
"$ROOT_DIR/scripts/build_backend_runtime.sh"

echo "Creating app bundle..."
mkdir -p "$MACOS_DIR" "$BACKEND_RUNTIME_DIR"

cp "$BIN_PATH" "$MACOS_DIR/Loquor"
chmod +x "$MACOS_DIR/Loquor"

echo "Packaging app icon..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Loquor</string>
  <key>CFBundleIdentifier</key>
  <string>com.gregoryklein.loquor</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Loquor</string>
  <key>CFBundleDisplayName</key>
  <string>Loquor</string>
  <key>CFBundleIconFile</key>
  <string>Loquor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Loquor uses the microphone to transcribe speech locally.</string>
</dict>
</plist>
PLIST

echo "Copying Python backend..."
rsync -a \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  "$ROOT_DIR/dist/loquor-backend/" \
  "$BACKEND_RUNTIME_DIR/"

echo "Bundle created at: $APP_DIR"
