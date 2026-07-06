#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LLAMA_CPP_REF="${LLAMA_CPP_REF:-master}"
LLAMA_DIR="$ROOT_DIR/llama.cpp"

if [ -d "$LLAMA_DIR/.git" ]; then
  echo "llama.cpp already present at $LLAMA_DIR"
  exit 0
fi

rm -rf "$LLAMA_DIR"
git clone --depth 1 --branch "$LLAMA_CPP_REF" https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"

echo "llama.cpp fetched to $LLAMA_DIR"
