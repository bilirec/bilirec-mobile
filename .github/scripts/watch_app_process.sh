#!/usr/bin/env sh
set -u

if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
  echo "Usage: watch_app_process.sh <package> <flutter_pid> [missing_grace_seconds] [poll_seconds] [startup_timeout_seconds]" >&2
  exit 2
fi

PACKAGE_NAME="$1"
FLUTTER_PID="$2"
MISSING_GRACE_SECONDS="${3:-90}"
POLL_SECONDS="${4:-10}"
STARTUP_TIMEOUT_SECONDS="${5:-180}"
DEVICE_SERIAL="${ANDROID_SERIAL:-emulator-5554}"

is_positive_integer() {
  value="$1"
  case "$value" in
    ''|*[!0-9]*|0)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

if ! is_positive_integer "$FLUTTER_PID" ||
   ! is_positive_integer "$MISSING_GRACE_SECONDS" ||
   ! is_positive_integer "$POLL_SECONDS" ||
   ! is_positive_integer "$STARTUP_TIMEOUT_SECONDS"; then
  echo "watch_app_process.sh: numeric arguments must be positive integers" >&2
  exit 2
fi

log_line() {
  message="$1"
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '[app-watch][%s] %s\n' "$ts" "$message"
}

flutter_process_alive() {
  kill -0 "$FLUTTER_PID" 2>/dev/null
}

device_app_pid() {
  adb -s "$DEVICE_SERIAL" shell pidof "$PACKAGE_NAME" 2>/dev/null |
    tr -d '\r' |
    awk 'NF { print $1; exit }'
}

started_at="$(date +%s)"
app_seen=0
missing_since=""
last_state=""

log_line "start package=$PACKAGE_NAME flutter_pid=$FLUTTER_PID device=$DEVICE_SERIAL startup_timeout=${STARTUP_TIMEOUT_SECONDS}s missing_grace=${MISSING_GRACE_SECONDS}s poll=${POLL_SECONDS}s"

while flutter_process_alive; do
  now="$(date +%s)"
  app_pid="$(device_app_pid || true)"

  if [ -n "$app_pid" ]; then
    if [ "$app_seen" -eq 0 ]; then
      app_seen=1
      missing_since=""
      last_state="running"
      log_line "app process detected pid=$app_pid"
    elif [ -n "$missing_since" ]; then
      log_line "app process recovered pid=$app_pid"
      missing_since=""
      last_state="running"
    fi
  elif [ "$app_seen" -eq 0 ]; then
    elapsed=$((now - started_at))
    if [ "$last_state" != "starting" ]; then
      last_state="starting"
      log_line "waiting for app process"
    fi
    if [ "$elapsed" -ge "$STARTUP_TIMEOUT_SECONDS" ]; then
      log_line "app did not start within ${STARTUP_TIMEOUT_SECONDS}s; stopping flutter test pid=$FLUTTER_PID"
      kill "$FLUTTER_PID" 2>/dev/null || true
      exit 0
    fi
  else
    if [ -z "$missing_since" ]; then
      missing_since="$now"
      last_state="missing"
      log_line "app process disappeared; grace period=${MISSING_GRACE_SECONDS}s"
    else
      missing_for=$((now - missing_since))
      if [ "$missing_for" -ge "$MISSING_GRACE_SECONDS" ]; then
        log_line "app process stayed missing for ${MISSING_GRACE_SECONDS}s; stopping flutter test pid=$FLUTTER_PID"
        kill "$FLUTTER_PID" 2>/dev/null || true
        exit 0
      fi
    fi
  fi

  sleep "$POLL_SECONDS"
done

log_line "flutter test process exited; watcher stopping"
