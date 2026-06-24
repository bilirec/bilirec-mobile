# CI Performance Monitoring Scripts

This directory contains external performance monitors used by GitHub Actions for the Android stress tests.

## `perf_monitor.sh`

A background sampler for Android emulator runs that records:

- `dumpsys meminfo` total PSS memory for `org.bilirec.bilirec`
- CPU from `/proc/<pid>/stat` tick deltas (preferred), computed with `resource_monitor.dart`-compatible semantics (process CPU over wall time, divide by safe CPU core count; fallback cores = `8`), with `dumpsys cpuinfo` fallback

It runs in **warn-only** mode by default:

- RAM warnings are emitted when usage exceeds the configured threshold.
- CPU warnings are emitted when usage exceeds the configured threshold.
- The script does **not** fail the workflow by itself.

### Suggested usage

```bash
sh ./.github/scripts/perf_monitor.sh \
  --package org.bilirec.bilirec \
  --job-name service-toggle \
  --interval 5 \
  --ram-warn 900 \
  --cpu-warn 95 \
  --mode warn \
  --log .ci/perf-monitor/service-toggle.log \
  --summary .ci/perf-monitor/service-toggle.summary
```

### Future block mode

The script already accepts `--mode block` so the workflow can later be upgraded to
fail on repeated warnings without changing the monitor interface.

## `run_stress_with_monitor.sh`

Wrapper script for emulator stress tests. It installs APK, grants permissions,
starts `perf_monitor.sh` in the background, runs one integration test file (with caller-provided `CI` flag),
then stops monitoring and returns the original `flutter test` exit code.

The workflow calls this wrapper as a **single command line** to avoid command
splitting pitfalls inside `reactivecircus/android-emulator-runner`.

## `cleanup_emulator.sh`

Force-kills the Android emulator and related processes (`qemu-system`,
`crashpad_handler`) after tests complete. This prevents GitHub Actions from
hanging indefinitely when `android-emulator-runner` tries to shut down API 29
emulators (known deadlock in issues #373 / #385).

Called automatically by `run_stress_with_monitor.sh` and inline emulator scripts.

## `free_disk_before_emulator.sh`

Reclaims disk space after `flutter build apk --debug` and before launching the
emulator in pre-build integration jobs. It removes Gradle/build intermediates
while keeping `build/app/outputs/flutter-apk/app-debug.apk` intact.

It does **not** run `flutter clean` (which would delete the pre-built APK) and
does **not** touch `~/.pub-cache` (managed separately by `subosito/flutter-action`
with `cache: true`).

## AVD / system image caching

`setup-flutter-android` caches:

- `~/.android/avd/*`
- `~/.android/adb*`
- `/usr/local/lib/android/sdk/system-images/*`

Cache key suffix: `v2` (includes system images; older `v1` entries are ignored).

For **API 29**, the setup action skips `Create AVD and generate snapshot` to
avoid running `android-emulator-runner` twice in one job. The test step is the
only emulator launch, which still populates the cache at job end on success.
API 34/36 still warm the AVD snapshot on cache miss.

