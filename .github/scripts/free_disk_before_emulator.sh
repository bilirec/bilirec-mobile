#!/usr/bin/env sh
set -eu

echo "=== Free disk before emulator (keep debug APK) ==="
rm -rf android/.gradle/caches android/build build/app/intermediates build/native_assets 2>/dev/null || true

if [ ! -f build/app/outputs/flutter-apk/app-debug.apk ]; then
  echo "ERROR: debug APK missing after cleanup" >&2
  exit 1
fi

df -h
