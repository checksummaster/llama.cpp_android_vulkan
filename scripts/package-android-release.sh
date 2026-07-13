#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_DIR="${1:-$ROOT_DIR/builds/android/build-android-vulkan}"
DIST_DIR="${2:-$ROOT_DIR/dist}"
PACKAGE_NAME="${3:-llama-android-arm64-vulkan.zip}"

case "$BUILD_DIR" in
  /*) ;;
  *) BUILD_DIR="$ROOT_DIR/$BUILD_DIR" ;;
esac

case "$DIST_DIR" in
  /*) ;;
  *) DIST_DIR="$ROOT_DIR/$DIST_DIR" ;;
esac

BIN_DIR="$BUILD_DIR/bin"
STAGE_DIR="$DIST_DIR/llama-android-arm64-vulkan"
OUT_ZIP="$DIST_DIR/$PACKAGE_NAME"

if [ ! -d "$BIN_DIR" ]; then
  echo "Missing build output directory: $BIN_DIR" >&2
  exit 1
fi

has_shared_libs=0
if [ -n "$(find "$BIN_DIR" -maxdepth 1 -type f -name '*.so' -print -quit)" ]; then
  has_shared_libs=1
fi

rm -rf "$DIST_DIR/llama-android-arm64-vulkan" "$OUT_ZIP"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

copy_binary() {
  local src="$1"
  local dst="$2"
  if [ ! -f "$src" ]; then
    echo "Missing binary: $src" >&2
    exit 1
  fi
  cp -a "$src" "$dst"
}

if [ "$has_shared_libs" -eq 1 ]; then
  echo "Android release package is static-only; shared libraries were found in $BIN_DIR" >&2
  echo "Rebuild with static linking or package manually if you need dynamic dependencies." >&2
  exit 1
else
  copy_binary "$BIN_DIR/llama-cli" "$STAGE_DIR/llama-cli"
  copy_binary "$BIN_DIR/llama-server" "$STAGE_DIR/llama-server"
  chmod +x "$STAGE_DIR/llama-cli" "$STAGE_DIR/llama-server"
fi

(cd "$DIST_DIR" && zip -qr "$OUT_ZIP" "llama-android-arm64-vulkan")

echo "$OUT_ZIP"
