#!/bin/bash

# Get the absolute path of the directory where THIS script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -x "$SCRIPT_DIR/android-ndk-r27d/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ] \
  || [ ! -x "$SCRIPT_DIR/vulkan-sdk/1.4.341.0/x86_64/bin/glslc" ] \
  || [ ! -d "$SCRIPT_DIR/llama.cpp/.git" ]; then
  bash "$SCRIPT_DIR/scripts/download-deps.sh"
fi

# 1. Set the absolute path to your downloaded Android NDK
export ANDROID_NDK="${ANDROID_NDK:-$SCRIPT_DIR/android-ndk-r27d}"
export PATH="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-$SCRIPT_DIR/llama.cpp}"

LOCAL_VULKAN_SDK="$SCRIPT_DIR/vulkan-sdk/1.4.341.0/x86_64"
if [ -d "$LOCAL_VULKAN_SDK" ]; then
  export VULKAN_SDK="$LOCAL_VULKAN_SDK"
fi

# Some Windows/WSL extractions preserve NDK symlinks as plain text files.
# Repair the compiler launchers so CMake can invoke clang with the original args.
NDK_BIN="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
repair_ndk_link() {
  local path="$1"
  local target="$2"
  if [ -f "$path" ] && [ ! -L "$path" ]; then
    ln -sf "$target" "$path"
  fi
}

repair_ndk_link "$NDK_BIN/clang" clang-18
repair_ndk_link "$NDK_BIN/clang++" clang-18
repair_ndk_link "$NDK_BIN/ld" lld
repair_ndk_link "$NDK_BIN/ld.lld" lld
repair_ndk_link "$NDK_BIN/ld64.lld" lld
repair_ndk_link "$NDK_BIN/lld-link" lld
repair_ndk_link "$NDK_BIN/llvm-addr2line" llvm-symbolizer
repair_ndk_link "$NDK_BIN/llvm-dlltool" llvm-ar
repair_ndk_link "$NDK_BIN/llvm-lib" llvm-ar
repair_ndk_link "$NDK_BIN/llvm-ranlib" llvm-ar
repair_ndk_link "$NDK_BIN/llvm-readelf" llvm-readobj
repair_ndk_link "$NDK_BIN/llvm-strip" llvm-objcopy
repair_ndk_link "$NDK_BIN/llvm-windres" llvm-rc
repair_ndk_link "$NDK_BIN/wasm-ld" lld

GLSLC_DIR="$ANDROID_NDK/shader-tools/linux-x86_64"
if [ -f "$GLSLC_DIR/libc++.so" ] && [ ! -L "$GLSLC_DIR/libc++.so" ]; then
  ln -sf "$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/lib/x86_64-unknown-linux-gnu/libc++.so" \
    "$GLSLC_DIR/libc++.so"
fi

VULKAN_GLSLC_EXECUTABLE="${VULKAN_GLSLC_EXECUTABLE:-}"
if [ -z "$VULKAN_GLSLC_EXECUTABLE" ]; then
  if [ -n "${VULKAN_SDK:-}" ] && [ -x "$VULKAN_SDK/bin/glslc" ]; then
    VULKAN_GLSLC_EXECUTABLE="$VULKAN_SDK/bin/glslc"
  elif command -v glslc >/dev/null 2>&1; then
    VULKAN_GLSLC_EXECUTABLE="$(command -v glslc)"
  else
    VULKAN_GLSLC_EXECUTABLE="$GLSLC_DIR/glslc"
  fi
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
  SPIRV_HEADERS_DIR="$SCRIPT_DIR/cmake/SPIRV-Headers"
fi

echo "Using Vulkan SDK: ${VULKAN_SDK:-<none>}"
echo "Using glslc: $VULKAN_GLSLC_EXECUTABLE"
echo "Using SPIRV-Headers: $SPIRV_HEADERS_DIR"

# 2. Create and move into a build directory
rm -rf builds/android/build-android-vulkan
mkdir -p builds/android/build-android-vulkan
cd builds/android/build-android-vulkan

# 3. Configure the build pointing directly to the llama.cpp folder
cmake "$LLAMA_CPP_DIR" \
  -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_ABI="arm64-v8a" \
  -DANDROID_PLATFORM=android-34 \
  -DANDROID_STL=c++_static \
  -DVulkan_INCLUDE_DIR="$VULKAN_SDK/include" \
  -DVulkan_GLSLC_EXECUTABLE="$VULKAN_GLSLC_EXECUTABLE" \
  -DSPIRV-Headers_DIR="$SPIRV_HEADERS_DIR" \
  -DGGML_VULKAN=ON

# 4. Compile the binaries
cmake --build . --config Release -j$(nproc)
