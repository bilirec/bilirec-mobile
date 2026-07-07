import 'package:bilirec/shared/app_update_service.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'test_support/in_memory_shared_preferences_async_platform.dart';

void main() {
  final fakeAsyncPrefs = InMemorySharedPreferencesAsyncPlatform();
  final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance = fakeAsyncPrefs;
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
  });

  setUp(() {
    fakeAsyncPrefs.reset();
  });

  group('AppUpdateService.normalizeVersionIdentifier', () {
    test('removes v prefix and build suffix', () {
      expect(
        AppUpdateService.normalizeVersionIdentifier('v1.2.3+45'),
        '1.2.3',
      );
      expect(
        AppUpdateService.normalizeVersionIdentifier('v.2.0.1-beta.4'),
        '2.0.1',
      );
    });

    test('maps non-numeric segment to 0', () {
      expect(
        AppUpdateService.normalizeVersionIdentifier('1.2.x'),
        '1.2.0',
      );
    });
  });

  group('AppUpdateService.shouldSkipPromptForRelease', () {
    test('returns true when normalized versions are equal', () {
      expect(
        AppUpdateService.shouldSkipPromptForRelease(
          releaseVersion: '1.3.0',
          skippedVersion: 'v1.3.0+5',
        ),
        isTrue,
      );
    });

    test('returns false when versions differ', () {
      expect(
        AppUpdateService.shouldSkipPromptForRelease(
          releaseVersion: '1.3.1',
          skippedVersion: '1.3.0',
        ),
        isFalse,
      );
    });
  });

  group('Preferences skipped update version', () {
    test('persists and clears skipped version', () async {
      await Preferences.setSkippedUpdateVersion('1.9.0');
      expect(await Preferences.getSkippedUpdateVersion(), '1.9.0');

      await Preferences.setSkippedUpdateVersion('');
      expect(await Preferences.getSkippedUpdateVersion(), isNull);
    });
  });
}
