#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-$ROOT_DIR/llama.cpp}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/builds/linux/build-linux-aarch64-vulkan}"
LOCAL_VULKAN_SDK="$ROOT_DIR/vulkan-sdk/1.4.341.0/x86_64"

case "$BUILD_DIR" in
  /*) ;;
  *) BUILD_DIR="$ROOT_DIR/$BUILD_DIR" ;;
esac

if [ ! -d "$LLAMA_CPP_DIR/.git" ]; then
  echo "Missing llama.cpp checkout at: $LLAMA_CPP_DIR" >&2
  exit 1
fi

if [ ! -f "$LLAMA_CPP_DIR/cmake/arm64-linux-clang.cmake" ]; then
  echo "Missing upstream Linux ARM64 toolchain file in llama.cpp" >&2
  exit 1
fi

find_executable() {
  for candidate in "$@"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

find_file() {
  for candidate in "$@"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

VULKAN_GLSLC_EXECUTABLE="${VULKAN_GLSLC_EXECUTABLE:-}"
if [ -z "$VULKAN_GLSLC_EXECUTABLE" ]; then
  if [ -z "${VULKAN_SDK:-}" ] && [ -x "$LOCAL_VULKAN_SDK/bin/glslc" ]; then
    VULKAN_SDK="$LOCAL_VULKAN_SDK"
  fi

  if [ -n "${VULKAN_SDK:-}" ] && [ -x "$VULKAN_SDK/bin/glslc" ]; then
    VULKAN_GLSLC_EXECUTABLE="$VULKAN_SDK/bin/glslc"
  elif command -v glslc >/dev/null 2>&1; then
    VULKAN_GLSLC_EXECUTABLE="$(command -v glslc)"
  else
    echo "Set VULKAN_SDK or VULKAN_GLSLC_EXECUTABLE so shaders can be built." >&2
    exit 1
  fi
fi

VULKAN_INCLUDE_DIR="${VULKAN_INCLUDE_DIR:-}"
if [ -z "${VULKAN_SDK:-}" ] && [ -d "$LOCAL_VULKAN_SDK/include" ]; then
  VULKAN_SDK="$LOCAL_VULKAN_SDK"
fi
if [ -z "$VULKAN_INCLUDE_DIR" ] && [ -n "${VULKAN_SDK:-}" ] && [ -d "$VULKAN_SDK/include" ]; then
  VULKAN_INCLUDE_DIR="$VULKAN_SDK/include"
fi

VULKAN_LIBRARY="${VULKAN_LIBRARY:-}"
if [ -z "$VULKAN_LIBRARY" ]; then
  VULKAN_LIBRARY="$(find_file \
    /usr/lib/aarch64-linux-gnu/libvulkan.so \
    /usr/aarch64-linux-gnu/lib/libvulkan.so \
    /usr/lib/aarch64-linux-gnu/libvulkan.so.1 \
    /usr/aarch64-linux-gnu/lib/libvulkan.so.1 \
    /lib/aarch64-linux-gnu/libvulkan.so \
    /lib/aarch64-linux-gnu/libvulkan.so.1 \
    || true)"
fi

SPIRV_HEADERS_DIR="${SPIRV_HEADERS_DIR:-}"
if [ -z "$SPIRV_HEADERS_DIR" ] && [ -n "${VULKAN_SDK:-}" ]; then
  for candidate in \
    "$VULKAN_SDK/share/cmake/SPIRV-Headers" \
    "$VULKAN_SDK/lib/cmake/SPIRV-Headers" \
    "$VULKAN_SDK/SPIRV-Headers"; do
    if [ -f "$candidate/SPIRV-HeadersConfig.cmake" ]; then
      SPIRV_HEADERS_DIR="$candidate"
      break
    fi
  done
fi
if [ -z "$SPIRV_HEADERS_DIR" ]; then
  SPIRV_HEADERS_DIR="$ROOT_DIR/cmake/SPIRV-Headers"
fi

if [ -z "${VULKAN_SDK:-}" ]; then
  echo "No Vulkan SDK found. Expected $LOCAL_VULKAN_SDK or set VULKAN_SDK." >&2
  exit 1
fi
if [ -z "$VULKAN_LIBRARY" ]; then
  echo "No Vulkan library found for the Linux ARM64 target." >&2
  echo "Install an arm64 Vulkan dev package or set VULKAN_LIBRARY to libvulkan.so." >&2
  exit 1
fi

VULKAN_SDK_LABEL="${VULKAN_SDK:-<none>}"
if [ -n "${VULKAN_SDK:-}" ] && [ "$VULKAN_SDK" = "$LOCAL_VULKAN_SDK" ]; then
  VULKAN_SDK_LABEL="$VULKAN_SDK (host tools only)"
fi

# The Linux release package does not need the embedded web UI.
# Leave this overridable for local experiments.
LLAMA_BUILD_UI="${LLAMA_BUILD_UI:-OFF}"
LLAMA_USE_PREBUILT_UI="${LLAMA_USE_PREBUILT_UI:-OFF}"

HOST_CLANG="$(find_executable "$(command -v clang 2>/dev/null || true)" "$(command -v clang-18 2>/dev/null || true)" "$(command -v clang-17 2>/dev/null || true)" "$(command -v clang-16 2>/dev/null || true)" || true)"
HOST_CLANGXX="$(find_executable "$(command -v clang++ 2>/dev/null || true)" "$(command -v clang++-18 2>/dev/null || true)" "$(command -v clang++-17 2>/dev/null || true)" "$(command -v clang++-16 2>/dev/null || true)" || true)"
HOST_LLD="$(find_executable "$(command -v ld.lld 2>/dev/null || true)" "$(command -v lld 2>/dev/null || true)" "$(command -v ld.lld-18 2>/dev/null || true)" "$(command -v ld.lld-17 2>/dev/null || true)" "$(command -v ld.lld-16 2>/dev/null || true)" || true)"
HOST_AARCH64_GCC="$(find_executable "$(command -v aarch64-linux-gnu-gcc 2>/dev/null || true)" || true)"
HOST_AARCH64_GXX="$(find_executable "$(command -v aarch64-linux-gnu-g++ 2>/dev/null || true)" || true)"

COMPILER_MODE=""
if [ -n "$HOST_AARCH64_GCC" ] && [ -n "$HOST_AARCH64_GXX" ]; then
  COMPILER_MODE="gcc"
elif [ -n "$HOST_CLANG" ] && [ -n "$HOST_CLANGXX" ] && [ -n "$HOST_LLD" ]; then
  COMPILER_MODE="clang"
else
  echo "Missing compiler toolchain for Linux ARM64 build." >&2
  echo "Install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu, or clang/clang++ plus lld, in WSL." >&2
  exit 1
fi

echo "Using llama.cpp: $LLAMA_CPP_DIR"
echo "Using build dir: $BUILD_DIR"
echo "Using Vulkan SDK: $VULKAN_SDK_LABEL"
echo "Using glslc: $VULKAN_GLSLC_EXECUTABLE"
echo "Using Vulkan include dir: ${VULKAN_INCLUDE_DIR:-<default>}"
echo "Using Vulkan library: $VULKAN_LIBRARY"
echo "Using SPIRV-Headers: $SPIRV_HEADERS_DIR"
echo "Using compiler mode: $COMPILER_MODE"
if [ "$COMPILER_MODE" = "clang" ]; then
  echo "Using C compiler: $HOST_CLANG"
  echo "Using CXX compiler: $HOST_CLANGXX"
  echo "Using linker: $HOST_LLD"
else
  echo "Using C compiler: $HOST_AARCH64_GCC"
  echo "Using CXX compiler: $HOST_AARCH64_GXX"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake_args=("$LLAMA_CPP_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DGGML_VULKAN=ON -DLLAMA_BUILD_UI="$LLAMA_BUILD_UI" -DLLAMA_USE_PREBUILT_UI="$LLAMA_USE_PREBUILT_UI" -DVulkan_GLSLC_EXECUTABLE="$VULKAN_GLSLC_EXECUTABLE" -DVulkan_LIBRARY="$VULKAN_LIBRARY" -DSPIRV-Headers_DIR="$SPIRV_HEADERS_DIR")

if [ "$COMPILER_MODE" = "clang" ]; then
  cmake_args+=(
    -DCMAKE_TOOLCHAIN_FILE="$LLAMA_CPP_DIR/cmake/arm64-linux-clang.cmake"
    -DCMAKE_C_COMPILER="$HOST_CLANG"
    -DCMAKE_CXX_COMPILER="$HOST_CLANGXX"
    -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld
    -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld
    -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld
  )
else
  cmake_args+=(
    -DCMAKE_SYSTEM_NAME=Linux
    -DCMAKE_SYSTEM_PROCESSOR=arm64
    -DCMAKE_C_COMPILER="$HOST_AARCH64_GCC"
    -DCMAKE_CXX_COMPILER="$HOST_AARCH64_GXX"
    -DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu
    -DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-gnu
  )
fi

if [ -n "$VULKAN_INCLUDE_DIR" ]; then
  cmake_args+=("-DVulkan_INCLUDE_DIR=$VULKAN_INCLUDE_DIR")
fi

cmake "${cmake_args[@]}"

cmake --build . --config Release -j"$(nproc)"
