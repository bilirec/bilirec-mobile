#!/usr/bin/env sh
# Force-kill Android emulator processes to prevent GHA hang on API 29 and below.
# See: reactivecircus/android-emulator-runner issues #373, #385

echo "=== 測試結束，主動清理模擬器進程防止 GHA 卡死 ==="
adb -s emulator-5554 emu kill 2>/dev/null || true
sleep 3
pkill -9 -f "qemu-system" || true
pkill -9 -f "crashpad_handler" || true
