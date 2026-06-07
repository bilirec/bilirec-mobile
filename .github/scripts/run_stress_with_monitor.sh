#!/usr/bin/env sh
set -eu

if [ "$#" -ne 8 ]; then
  echo "Usage: run_stress_with_monitor.sh <test_file> <job_name> <log_file> <summary_file> <interval_seconds> <ram_warn_mb> <cpu_warn_percent> <ci_flag>" >&2
  exit 2
fi

TEST_FILE="$1"
JOB_NAME="$2"
LOG_FILE="$3"
SUMMARY_FILE="$4"
INTERVAL_SECONDS="$5"
RAM_WARN_MB="$6"
CPU_WARN_PERCENT="$7"
CI_FLAG="$8"

echo "=== 模擬器啟動成功，開始手動安裝 APK ==="
adb install build/app/outputs/flutter-apk/app-debug.apk

echo "=== 預先授予前景服務與通知權限 ==="
adb shell pm grant org.bilirec.bilirec android.permission.POST_NOTIFICATIONS

echo "=== 啟動外部效能監控（RAM/CPU，只告警不阻斷）==="
sh ./.github/scripts/perf_monitor.sh --package org.bilirec.bilirec --job-name "$JOB_NAME" --interval "$INTERVAL_SECONDS" --ram-warn "$RAM_WARN_MB" --cpu-warn "$CPU_WARN_PERCENT" --mode warn --log "$LOG_FILE" --summary "$SUMMARY_FILE" &
MONITOR_PID=$!
cleanup() { kill "$MONITOR_PID" 2>/dev/null || true; wait "$MONITOR_PID" 2>/dev/null || true; }
trap cleanup 0 INT TERM

adb logcat -c
echo "=== 開始執行 Flutter 壓力測試: $TEST_FILE ==="
set +e
flutter test "$TEST_FILE" --reporter=expanded --dart-define=CI="$CI_FLAG"
FLUTTER_STATUS=$?
set -e

if [ "$FLUTTER_STATUS" -ne 0 ]; then
  echo "===================================================="
  echo "⚠️ 偵測到測試失敗或 App 崩潰！正在撈取 Android Logcat 崩潰日誌..."
  echo "===================================================="

  # 只保留 bilirec app 與 cgo/FFmpeg hook 相關錯誤日誌
  # 若需完整錯誤可改回：adb logcat -d *:E
  adb logcat -d *:E \
    | grep -E 'org\.bilirec\.bilirec|BiliRec_FFmpegHook|cgo|CGO|libgojni|libffmpegkit|FFMPEG' \
    | tail -n 1000 \
    || true

  echo "===================================================="
fi

cleanup
trap - 0 INT TERM

if [ -f "$SUMMARY_FILE" ]; then
  echo "=== 壓測效能摘要 ($JOB_NAME) ==="
  cat "$SUMMARY_FILE"
fi

echo "=== 壓測結束: $TEST_FILE ==="
exit $FLUTTER_STATUS
