#!/usr/bin/env sh
set -u

PKG_NAME="org.bilirec.bilirec"
SAMPLE_INTERVAL_SECONDS=5
RAM_WARN_MB=900
CPU_WARN_PERCENT=95
MODE="warn"
JOB_NAME="perf-monitor"
LOG_FILE=""
SUMMARY_FILE=""
STOP_REQUESTED=0
SAMPLE_COUNT=0
WARNING_COUNT=0
MAX_RAM_MB=0
MAX_CPU_PERCENT=0
FIRST_WARNING_AT=""
RAM_WARNING_COUNT=0
CPU_WARNING_COUNT=0
SUMMARY_WRITTEN=0
CLK_TCK=100
CPU_COMPAT_DIVISOR=8
LAST_APP_CPU_MS=""
LAST_WALL_MS=""
LAST_CPU_PID=""

usage() {
  cat <<'EOF'
Usage: perf_monitor.sh [options]

Options:
  --package <name>         Android package name to monitor
  --interval <seconds>     Sampling interval in seconds (default: 5)
  --ram-warn <MB>          RAM warning threshold in MB (default: 900)
  --cpu-warn <percent>     CPU warning threshold in percent (default: 95)
  --mode <warn|block>      Current mode; warn only by default, block reserved for future use
  --job-name <name>        Label used in log output
  --log <path>             Write detailed sample log to this file
  --summary <path>         Write final summary to this file
EOF
}

log_line() {
  message="$1"
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '[%s][%s] %s\n' "$JOB_NAME" "$ts" "$message"
}

write_summary() {
  if [ "$SUMMARY_WRITTEN" -eq 1 ]; then
    return
  fi
  SUMMARY_WRITTEN=1

  status="stopped"
  if [ "$STOP_REQUESTED" -eq 1 ]; then
    status="terminated"
  fi

  summary="status=$status\nsamples=$SAMPLE_COUNT\nwarnings=$WARNING_COUNT\nram_warnings=$RAM_WARNING_COUNT\ncpu_warnings=$CPU_WARNING_COUNT\nmax_ram_mb=$MAX_RAM_MB\nmax_cpu_percent=$MAX_CPU_PERCENT\nmode=$MODE\npackage=$PKG_NAME\ninterval_seconds=$SAMPLE_INTERVAL_SECONDS\nram_warn_mb=$RAM_WARN_MB\ncpu_warn_percent=$CPU_WARN_PERCENT\nfirst_warning_at=${FIRST_WARNING_AT:-}\n"

  if [ -n "$SUMMARY_FILE" ]; then
    mkdir -p "$(dirname "$SUMMARY_FILE")"
    printf '%b' "$summary" > "$SUMMARY_FILE"
  fi

  log_line "summary status=$status samples=$SAMPLE_COUNT warnings=$WARNING_COUNT max_ram_mb=$MAX_RAM_MB max_cpu_percent=$MAX_CPU_PERCENT"
}

cleanup() {
  STOP_REQUESTED=1
  write_summary
}

trap cleanup INT TERM EXIT

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --package)
        PKG_NAME="${2:-}"
        shift 2
        ;;
      --interval)
        SAMPLE_INTERVAL_SECONDS="${2:-}"
        shift 2
        ;;
      --ram-warn)
        RAM_WARN_MB="${2:-}"
        shift 2
        ;;
      --cpu-warn)
        CPU_WARN_PERCENT="${2:-}"
        shift 2
        ;;
      --mode)
        MODE="${2:-}"
        shift 2
        ;;
      --job-name)
        JOB_NAME="${2:-}"
        shift 2
        ;;
      --log)
        LOG_FILE="${2:-}"
        shift 2
        ;;
      --summary)
        SUMMARY_FILE="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
}

normalize_number() {
  raw="$1"
  raw="$(printf '%s' "$raw" | tr -d '%,')"
  printf '%s' "$raw"
}

now_millis() {
  # Prefer millisecond precision; fall back to second precision if %N is unsupported.
  raw_ms="$(date +%s%3N 2>/dev/null || true)"
  case "$raw_ms" in
    ''|*[!0-9]*)
      sec="$(date +%s)"
      printf '%s' "$((sec * 1000))"
      ;;
    *)
      printf '%s' "$raw_ms"
      ;;
  esac
}

init_cpu_source() {
  # Prefer device clock ticks for /proc/<pid>/stat CPU calculation.
  raw_hz="$(adb shell "getconf CLK_TCK 2>/dev/null || echo 100" 2>/dev/null | tr -d '\r' | tail -n 1)"
  raw_hz="$(normalize_number "$raw_hz")"
  case "$raw_hz" in
    ''|*[!0-9]*)
      CLK_TCK=100
      ;;
    *)
      if [ "$raw_hz" -gt 0 ]; then
        CLK_TCK="$raw_hz"
      else
        CLK_TCK=100
      fi
      ;;
  esac

  raw_cores="$(adb shell "getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8" 2>/dev/null | tr -d '\r' | tail -n 1)"
  raw_cores="$(normalize_number "$raw_cores")"
  case "$raw_cores" in
    ''|*[!0-9]*)
      CPU_COMPAT_DIVISOR=8
      ;;
    *)
      if [ "$raw_cores" -gt 0 ] && [ "$raw_cores" -le 128 ]; then
        CPU_COMPAT_DIVISOR="$raw_cores"
      else
        CPU_COMPAT_DIVISOR=8
      fi
      ;;
  esac

}

read_cpu_from_dumpsys() {
   cpu_raw="$(adb shell "dumpsys cpuinfo" 2>/dev/null | grep -F "$PKG_NAME" | awk '{gsub(/%/, "", $1); sum += $1} END {if (sum == "") print 0; else print sum}' || true)"
   cpu_raw="$(normalize_number "$cpu_raw")"
   if [ -z "$cpu_raw" ]; then
     cpu_raw='0'
   fi
   cpu_percent="$(awk -v value="$cpu_raw" -v divisor="$CPU_COMPAT_DIVISOR" 'BEGIN { if (value == "" || value + 0 < 0 || divisor <= 0) { printf "%.1f", 0; exit } normalized = (value + 0) / divisor; if (normalized < 0) normalized = 0; if (normalized > 100) normalized = 100; printf "%.1f", normalized }')"
 }

read_cpu_sample() {
  pid="$(adb shell "pidof '$PKG_NAME'" 2>/dev/null | tr -d '\r' | awk '{print $1}')"
  if [ -z "$pid" ]; then
    LAST_APP_CPU_MS=""
    LAST_WALL_MS=""
    LAST_CPU_PID=""
    cpu_percent='0'
    return
  fi

  if [ "$LAST_CPU_PID" != "$pid" ]; then
    LAST_CPU_PID="$pid"
    LAST_APP_CPU_MS=""
    LAST_WALL_MS=""
  fi

  stat_line="$(adb shell "cat /proc/$pid/stat" 2>/dev/null | tr -d '\r' | tail -n 1)"
  if [ -z "$stat_line" ]; then
    read_cpu_from_dumpsys
    return
  fi

  # Align with resource_monitor.dart: (utime + stime) * 10 => app cpu milliseconds.
  app_cpu_ms="$(printf '%s\n' "$stat_line" | awk '{ if (NF >= 15) print ($14 + $15) * 10; }')"
  app_cpu_ms="$(normalize_number "$app_cpu_ms")"
  case "$app_cpu_ms" in
    ''|*[!0-9]*)
      read_cpu_from_dumpsys
      return
      ;;
  esac

  now_ms="$(now_millis)"
  if [ -z "$LAST_APP_CPU_MS" ] || [ -z "$LAST_WALL_MS" ]; then
    LAST_APP_CPU_MS="$app_cpu_ms"
    LAST_WALL_MS="$now_ms"
    cpu_percent='0'
    return
  fi

  delta_app_ms=$((app_cpu_ms - LAST_APP_CPU_MS))
  delta_wall_ms=$((now_ms - LAST_WALL_MS))
  LAST_APP_CPU_MS="$app_cpu_ms"
  LAST_WALL_MS="$now_ms"

  # Keep the same fallback intent as resource_monitor.dart (avoid divide-by-zero path).
  if [ "$delta_wall_ms" -le 0 ] || [ "$delta_app_ms" -le 0 ]; then
    cpu_percent='1'
    return
  fi

   # Keep CPU semantics aligned with lib/foreground/resource_monitor.dart:
   # process CPU over wall-clock, then divide by safe CPU core count.
   cpu_percent="$(awk -v app="$delta_app_ms" -v wall="$delta_wall_ms" -v divisor="$CPU_COMPAT_DIVISOR" 'BEGIN { if (wall <= 0 || app <= 0 || divisor <= 0) { printf "%.1f", 1.0; exit } value = (app / wall) * 100.0; value = value / divisor; if (value < 0) value = 0; if (value > 100) value = 100; printf "%.1f", value }')"
}

# Read one memory sample and one CPU sample per interval.
# CPU prefers /proc/<pid>/stat and falls back to dumpsys cpuinfo.
read_sample() {
  output="$(adb shell "dumpsys meminfo '$PKG_NAME'" 2>/dev/null || true)"

  # Parse meminfo output
  mem_kb="$(printf '%s' "$output" | awk '/TOTAL PSS:|TOTAL:/{print; exit}' | sed -E 's/.*TOTAL( PSS)?:[[:space:]]*([0-9]+).*/\2/' || true)"
   mem_kb="$(normalize_number "$mem_kb")"
   if [ -z "$mem_kb" ]; then
     mem_kb='0'
   fi
   case "$mem_kb" in
     ''|*[!0-9]*)
       mem_kb='0'
       ;;
   esac
   mem_mb="$(awk -v kb="$mem_kb" 'BEGIN { mb = kb / 1024.0; if (mb < 0) mb = 0; printf "%.1f", mb }')"

  read_cpu_sample
}

record_sample() {
   mem_mb="$1"
   cpu_percent="$2"
   now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

   SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
   if awk -v current="$mem_mb" -v max="$MAX_RAM_MB" 'BEGIN { exit !(current > max) }'; then
     MAX_RAM_MB="$mem_mb"
   fi

   if awk -v current="$cpu_percent" -v max="$MAX_CPU_PERCENT" 'BEGIN { exit !(current > max) }'; then
     MAX_CPU_PERCENT="$cpu_percent"
   fi

   mem_warn=0
   cpu_warn=0
   if awk -v current="$mem_mb" -v threshold="$RAM_WARN_MB" 'BEGIN { exit !(current > threshold) }'; then
     mem_warn=1
     RAM_WARNING_COUNT=$((RAM_WARNING_COUNT + 1))
   fi
   if awk -v current="$cpu_percent" -v threshold="$CPU_WARN_PERCENT" 'BEGIN { exit !(current > threshold) }'; then
     cpu_warn=1
     CPU_WARNING_COUNT=$((CPU_WARNING_COUNT + 1))
   fi

  if [ "$mem_warn" -eq 1 ] || [ "$cpu_warn" -eq 1 ]; then
    WARNING_COUNT=$((WARNING_COUNT + 1))
    if [ -z "$FIRST_WARNING_AT" ]; then
      FIRST_WARNING_AT="$now"
    fi
  fi

  status="ok"
  if [ "$mem_warn" -eq 1 ] && [ "$cpu_warn" -eq 1 ]; then
    status="mem+cpu-warning"
  elif [ "$mem_warn" -eq 1 ]; then
    status="mem-warning"
  elif [ "$cpu_warn" -eq 1 ]; then
    status="cpu-warning"
  fi

  line="[$JOB_NAME][$now] sample=$SAMPLE_COUNT mem_mb=$mem_mb cpu_percent=$cpu_percent status=$status"
  echo "$line"
  if [ -n "$LOG_FILE" ]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s\n' "$line" >> "$LOG_FILE"
  fi
}

main() {
  parse_args "$@"

  if [ -n "$LOG_FILE" ]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    : > "$LOG_FILE"
  fi
  if [ -n "$SUMMARY_FILE" ]; then
    mkdir -p "$(dirname "$SUMMARY_FILE")"
    : > "$SUMMARY_FILE"
  fi

  log_line "start package=$PKG_NAME interval=${SAMPLE_INTERVAL_SECONDS}s ram_warn_mb=$RAM_WARN_MB cpu_warn_percent=$CPU_WARN_PERCENT mode=$MODE"
  log_line "reserved future block mode variables: MODE=$MODE (warn only today; block can be enabled later)"
  init_cpu_source
  log_line "cpu source=/proc/<pid>/stat mode=resource_monitor_compatible cpu_cores=$CPU_COMPAT_DIVISOR(clk_tck=$CLK_TCK) fallback=dumpsys cpuinfo"

   while [ "$STOP_REQUESTED" -eq 0 ]; do
     read_sample
     record_sample "$mem_mb" "$cpu_percent"

     elapsed=0
     while [ "$elapsed" -lt "$SAMPLE_INTERVAL_SECONDS" ] && [ "$STOP_REQUESTED" -eq 0 ]; do
       sleep 1
       elapsed=$((elapsed + 1))
     done
   done
}

main "$@"



