#!/usr/bin/env bash
set -euo pipefail

# Run a local llama-cli example, downloading the model into the current
# directory if it is missing.
#
# Usage:
#   MODEL_URL=... ./scripts/run-llama-example.sh
#
# The script always uses gemma-4-e2b.Q4_K_M.gguf in the current directory.
# If the file is missing, it downloads it from MODEL_URL.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LLAMA_CLI="${LLAMA_CLI:-$ROOT_DIR/builds/android/build-android-vulkan/bin/llama-cli}"
MODEL_FILE="gemma-4-e2b.Q4_K_M.gguf"
PROMPT="${PROMPT:-Say hello in one short sentence.}"

if [ ! -x "$LLAMA_CLI" ]; then
  if [ -x "$PWD/llama-cli" ]; then
    LLAMA_CLI="$PWD/llama-cli"
  elif [ -x "$ROOT_DIR/dist/llama-android-arm64-vulkan/llama-cli" ]; then
    LLAMA_CLI="$ROOT_DIR/dist/llama-android-arm64-vulkan/llama-cli"
  else
    echo "Could not find llama-cli." >&2
    echo "Set LLAMA_CLI to the binary path or extract the Android package in this directory." >&2
    exit 1
  fi
fi

if [ ! -f "$MODEL_FILE" ]; then
  if [ -z "${MODEL_URL:-}" ]; then
    echo "Model file '$MODEL_FILE' is missing and no MODEL_URL was provided." >&2
    echo "Set MODEL_URL to the download URL for gemma-4-e2b.Q4_K_M.gguf." >&2
    exit 1
  fi

  echo "Downloading model to $MODEL_FILE"
  tmp_file="${MODEL_FILE}.download"
  rm -f "$tmp_file"
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail -o "$tmp_file" "$MODEL_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$tmp_file" "$MODEL_URL"
  else
    echo "Need curl or wget to download the model." >&2
    exit 1
  fi
  mv "$tmp_file" "$MODEL_FILE"
fi

exec "$LLAMA_CLI" -m "$MODEL_FILE" -p "$PROMPT" -n 32
