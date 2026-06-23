const int kBaseFlushPeriodSecs = 15;
const int kBaseConcurrentForFlush = 3;
const int kDefaultMaxConcurrentRecordings = 3;
const int kMaxFlushPeriodSecs = 45;

int computeFlushPeriodSecs(int maxConcurrent) {
  final scaled =
      (kBaseFlushPeriodSecs * maxConcurrent / kBaseConcurrentForFlush).round();
  return scaled.clamp(kBaseFlushPeriodSecs, kMaxFlushPeriodSecs);
}

int parseMaxConcurrentRecordings(Map<String, String> env) {
  return int.tryParse(env['MAX_CONCURRENT_RECORDINGS'] ?? '') ??
      kDefaultMaxConcurrentRecordings;
}

/// Updates [env] for microSD wear protection (SEQUENTIAL_WRITE + flush period).
Map<String, String> applyStorageProtectionEnv({
  required Map<String, String> env,
  required bool protectionEnabled,
  required int maxConcurrent,
}) {
  if (protectionEnabled) {
    env['SEQUENTIAL_WRITE'] = 'true';
    env['LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS'] =
        '${computeFlushPeriodSecs(maxConcurrent)}';
  } else {
    env['SEQUENTIAL_WRITE'] = 'false';
    env.remove('LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS');
  }
  return env;
}

bool isSequentialWriteEnabled(Map<String, String> env) {
  return (env['SEQUENTIAL_WRITE'] ?? '').trim().toLowerCase() == 'true';
}
