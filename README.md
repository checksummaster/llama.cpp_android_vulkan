# llama_android

This repo packages an Android arm64 Vulkan build of `llama.cpp` for use on a phone terminal.

## Local build

```sh
./android-vulkan.sh
```

The script builds against the local `llama.cpp` checkout when present, or the GitHub Actions workflow can clone upstream `llama.cpp` into that path.

## Release package

The release bundle contains:

- `llama-cli`
- `llama-server`
- `llama-server-cli`
- the required shared libraries from the Android build

The package also includes wrappers that set `LD_LIBRARY_PATH` so the binaries can run from a plain unzip on-device.

## Phone usage

```sh
chmod +x llama-cli llama-server llama-server-cli
./llama-cli -m /path/to/model.gguf -p "Hello"
./llama-server-cli -m /path/to/model.gguf
```

## GitHub release flow

Create a tag and push it. The workflow will build the Android package and attach the zip to the GitHub Release.
