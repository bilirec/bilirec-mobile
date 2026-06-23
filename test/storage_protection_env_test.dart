import 'package:bilirec/shared/storage_protection_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeFlushPeriodSecs', () {
    test('scales with max concurrent', () {
      expect(computeFlushPeriodSecs(3), 15);
      expect(computeFlushPeriodSecs(4), 20);
      expect(computeFlushPeriodSecs(5), 25);
      expect(computeFlushPeriodSecs(6), 30);
    });

    test('clamps to configured bounds', () {
      expect(computeFlushPeriodSecs(1), 15);
      expect(computeFlushPeriodSecs(100), 45);
    });
  });

  group('applyStorageProtectionEnv', () {
    test('enabled sets sequential write and flush period', () {
      final env = applyStorageProtectionEnv(
        env: <String, String>{},
        protectionEnabled: true,
        maxConcurrent: 3,
      );

      expect(env['SEQUENTIAL_WRITE'], 'true');
      expect(env['LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS'], '15');
    });

    test('disabled clears flush period', () {
      final env = applyStorageProtectionEnv(
        env: <String, String>{
          'SEQUENTIAL_WRITE': 'true',
          'LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS': '20',
        },
        protectionEnabled: false,
        maxConcurrent: 4,
      );

      expect(env['SEQUENTIAL_WRITE'], 'false');
      expect(env.containsKey('LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS'), isFalse);
    });

    test('enabled updates flush when concurrent changes', () {
      final env = applyStorageProtectionEnv(
        env: <String, String>{'MAX_CONCURRENT_RECORDINGS': '6'},
        protectionEnabled: true,
        maxConcurrent: 6,
      );

      expect(env['LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS'], '30');
    });
  });

  group('parseMaxConcurrentRecordings', () {
    test('falls back to default', () {
      expect(parseMaxConcurrentRecordings(const {}), 3);
      expect(
        parseMaxConcurrentRecordings(const {'MAX_CONCURRENT_RECORDINGS': '5'}),
        5,
      );
    });
  });
}
