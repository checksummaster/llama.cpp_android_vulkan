#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-r27d}"
VULKAN_SDK_VERSION="${VULKAN_SDK_VERSION:-1.4.341.0}"
LLAMA_CPP_REF="${LLAMA_CPP_REF:-master}"

NDK_DIR="$ROOT_DIR/android-ndk-${ANDROID_NDK_VERSION}"
VULKAN_DIR="$ROOT_DIR/vulkan-sdk/${VULKAN_SDK_VERSION}/x86_64"
LLAMA_DIR="$ROOT_DIR/llama.cpp"

download() {
  local url="$1"
  local out="$2"
  curl -L --fail --retry 3 --retry-delay 2 -o "$out" "$url"
}

if [ ! -x "$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ]; then
  mkdir -p "$ROOT_DIR"
  tmp_ndk_zip="$ROOT_DIR/android-ndk-${ANDROID_NDK_VERSION}-linux.zip"
  if [ ! -f "$tmp_ndk_zip" ]; then
    download "https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip" "$tmp_ndk_zip"
  fi
  rm -rf "$NDK_DIR"
  unzip -q "$tmp_ndk_zip" -d "$ROOT_DIR"
fi

if [ ! -x "$VULKAN_DIR/bin/glslc" ]; then
  mkdir -p "$ROOT_DIR/vulkan-sdk"
  tmp_vulkan_tar="$ROOT_DIR/vulkan-sdk/vulkansdk-linux-x86_64-${VULKAN_SDK_VERSION}.tar.xz"
  if [ ! -f "$tmp_vulkan_tar" ]; then
    download "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/linux/vulkansdk-linux-x86_64-${VULKAN_SDK_VERSION}.tar.xz" "$tmp_vulkan_tar"
  fi
  rm -rf "$ROOT_DIR/vulkan-sdk/${VULKAN_SDK_VERSION}"
  tar -xf "$tmp_vulkan_tar" -C "$ROOT_DIR/vulkan-sdk"
fi

bash "$SCRIPT_DIR/fetch-llama.sh"

echo "Dependencies are ready:"
echo "  ANDROID_NDK=$NDK_DIR"
echo "  VULKAN_SDK=$VULKAN_DIR"
echo "  LLAMA_CPP_DIR=$LLAMA_DIR"
