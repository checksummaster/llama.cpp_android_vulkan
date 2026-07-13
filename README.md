# llama_android

This repo packages an Android arm64 Vulkan build of `llama.cpp` for use on a phone terminal.

## Local build

If you want a fresh checkout to self-bootstrap, run:

```sh
bash scripts/download-deps.sh
```

Then build:

```sh
./scripts/android-vulkan.sh
```

The script builds against the local `llama.cpp` checkout when present, or the GitHub Actions workflow can clone upstream `llama.cpp` into that path.

## Runtime Check

If you are unsure whether your terminal is Android bionic or Linux glibc, run:

```sh
bash scripts/verify-runtime.sh
```

Use `scripts/android-vulkan.sh` only when it reports `runtime=android-bionic`. If it reports `runtime=linux-glibc`, use the Linux ARM64 build script instead.

## Release package

The release bundle contains two zips:

- `llama-android-arm64-vulkan.zip`
- `llama-linux-arm64-vulkan.zip`

The Android package contains:

- `llama-cli`
- `llama-server`
- the package is static-only and does not include shared libraries or wrapper scripts
The zip extracts to a single `llama-android-arm64-vulkan/` folder.

The Linux package has the same app binaries but targets a glibc-based Linux ARM64 runtime.

## Phone usage

```sh
chmod +x llama-cli llama-server
./llama-cli -m /path/to/model.gguf -p "Hello"
./llama-server -m /path/to/model.gguf
```

To auto-download a model into the current directory and then run `llama-cli`:

```sh
chmod +x scripts/run-llama-example.sh
MODEL_URL=https://.../gemma-4-e2b.Q4_K_M.gguf ./scripts/run-llama-example.sh
```

## Linux ARM64 Build

For a Linux AArch64 terminal environment, use:

```sh
bash scripts/build-linux-aarch64-vulkan.sh
```

This is for a glibc-based Linux userspace, not Android bionic. The script will use the bundled Vulkan SDK when present.
It works best with `gcc-aarch64-linux-gnu` and `g++-aarch64-linux-gnu` installed in WSL; `clang`/`clang++` plus `lld` is a fallback.
You also need an ARM64 Vulkan loader/dev library available to the build, usually via a target-arm64 `libvulkan.so` in your Linux sysroot.

## GitHub release flow

Create a tag and push it. The workflow will build the Android package and attach the zip to the GitHub Release.
It will also build and attach the Linux ARM64 package.
