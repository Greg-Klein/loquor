#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
PYINSTALLER_BIN="$VENV_DIR/bin/pyinstaller"
BUILD_DIR="$ROOT_DIR/build/backend-runtime"
DIST_DIR="$ROOT_DIR/dist/backend-runtime"
ENTRYPOINT="$ROOT_DIR/src/speech_to_text/backend_service.py"

if [ ! -x "$PYINSTALLER_BIN" ]; then
  echo "PyInstaller is required to build a portable Loquor backend." >&2
  echo "Install it in the project venv first:" >&2
  echo "  source .venv/bin/activate && pip install pyinstaller" >&2
  exit 1
fi

echo "Building standalone Python backend..."
rm -rf "$BUILD_DIR" "$DIST_DIR"

"$PYINSTALLER_BIN" \
  --noconfirm \
  --clean \
  --onedir \
  --name loquor-backend \
  --distpath "$ROOT_DIR/dist" \
  --workpath "$BUILD_DIR" \
  --specpath "$BUILD_DIR" \
  --paths "$ROOT_DIR/src" \
  --collect-submodules speech_to_text \
  --collect-submodules parakeet_mlx \
  --collect-submodules mlx \
  --collect-data parakeet_mlx \
  --collect-data mlx \
  --collect-binaries sounddevice \
  --collect-binaries soundfile \
  "$ENTRYPOINT"

echo "Standalone backend created at: $DIST_DIR"
