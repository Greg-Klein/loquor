#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Loquor.app"
TARGET_PATH="/Applications/Loquor.app"

"$ROOT_DIR/scripts/build_native_app.sh"
rm -rf "$TARGET_PATH"
cp -R "$APP_PATH" "$TARGET_PATH"

echo "Installed to: $TARGET_PATH"
