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
BACKEND_DIR="$RESOURCES_DIR/backend"
PYTHON_DIR="$RESOURCES_DIR/python"

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"

echo "Building Swift app in release mode..."
swift build -c release --package-path "$NATIVE_DIR"

BIN_PATH="$(swift build -c release --package-path "$NATIVE_DIR" --show-bin-path)/SpeechToTextNative"

echo "Creating app bundle..."
mkdir -p "$MACOS_DIR" "$BACKEND_DIR" "$PYTHON_DIR"

cp "$BIN_PATH" "$MACOS_DIR/Loquor"
chmod +x "$MACOS_DIR/Loquor"

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
mkdir -p "$BACKEND_DIR/src"
rsync -a \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  "$ROOT_DIR/src/speech_to_text" \
  "$BACKEND_DIR/src/"

echo "Copying Python runtime..."
rsync -a \
  --exclude 'share' \
  --exclude 'man' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude 'Activate.ps1' \
  --exclude 'activate' \
  --exclude 'activate.csh' \
  --exclude 'activate.fish' \
  "$ROOT_DIR/.venv/" \
  "$PYTHON_DIR/"

echo "Bundle created at: $APP_DIR"
