#!/usr/bin/env sh
set -u

DEVICE_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
TEMP_LOG="$(mktemp "${TMPDIR:-/tmp}/bilirec-logcat.XXXXXX")"

cleanup() {
  rm -f "$TEMP_LOG"
}
trap cleanup EXIT INT TERM

read_logcat() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 30s adb -s "$DEVICE_SERIAL" logcat -d -v threadtime
  else
    adb -s "$DEVICE_SERIAL" logcat -d -v threadtime
  fi
}

echo "=== Filtered Android logcat (device=$DEVICE_SERIAL) ==="

if ! read_logcat >"$TEMP_LOG" 2>&1; then
  echo "Unable to read logcat; raw adb output follows:"
  cat "$TEMP_LOG"
  exit 0
fi

if ! grep -E \
  '(^|[[:space:]])E/|AndroidRuntime|FATAL EXCEPTION|Fatal signal|SIG(SEGV|ABRT|BUS|ILL)|tombstoned|panic|org\.bilirec\.bilirec|BiliRec|BILIREC|Flutter|ForegroundService|flutter_foreground_task|libgojni|libffmpegkit|FFMPEG|bad color buffer' \
  "$TEMP_LOG"; then
  echo "No matching crash or Bilirec-related logcat lines were found."
fi
