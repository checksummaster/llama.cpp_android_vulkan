#!/usr/bin/env sh
set -eu

runtime="unknown"
details=""

if command -v getprop >/dev/null 2>&1; then
  android_sdk="$(getprop ro.build.version.sdk 2>/dev/null || true)"
  android_release="$(getprop ro.build.version.release 2>/dev/null || true)"
  android_abi="$(getprop ro.product.cpu.abi 2>/dev/null || true)"
  if [ -n "$android_sdk" ] || [ -n "$android_release" ] || [ -n "$android_abi" ]; then
    runtime="android-bionic"
    details="sdk=${android_sdk:-?} release=${android_release:-?} abi=${android_abi:-?}"
  fi
fi

if [ "$runtime" = "unknown" ] && command -v getconf >/dev/null 2>&1; then
  if libc_version="$(getconf GNU_LIBC_VERSION 2>/dev/null)"; then
    runtime="linux-glibc"
    details="$libc_version"
  fi
fi

if [ "$runtime" = "unknown" ] && [ -r /etc/os-release ]; then
  os_name="$(sed -n 's/^NAME=//p' /etc/os-release | head -n 1 | tr -d '"')"
  os_id="$(sed -n 's/^ID=//p' /etc/os-release | head -n 1 | tr -d '"')"
  details="os=${os_id:-?} name=${os_name:-?}"
fi

echo "runtime=${runtime}"
if [ -n "$details" ]; then
  echo "details=${details}"
fi

  case "$runtime" in
  android-bionic)
    echo "use=scripts/android-vulkan.sh"
    ;;
  linux-glibc)
    echo "use=scripts/build-linux-aarch64-vulkan.sh"
    ;;
  *)
    echo "use=unknown"
    ;;
esac
