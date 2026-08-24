import 'dart:io';

import 'package:bilirec/shared/app_update_service.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/unexpected_stop_preferences.dart';
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

  group('Preferences last seen installed version', () {
    test('persists and clears last seen version', () async {
      await Preferences.setLastSeenInstalledVersion('1.0.2');
      expect(await Preferences.getLastSeenInstalledVersion(), '1.0.2');

      await Preferences.setLastSeenInstalledVersion('');
      expect(await Preferences.getLastSeenInstalledVersion(), isNull);
    });
  });

  group('AppUpdateService first launch after update', () {
    AppUpdateService serviceWithVersion(String Function() version) {
      return AppUpdateService(currentAppVersionProvider: () async => version());
    }

    Future<void> runFirstLaunchHooks(AppUpdateService service) async {
      if (!await service.isFirstLaunchAfterUpdate()) {
        return;
      }
      await UnexpectedStopPreferences.consumePrompt();
      await service.acknowledgeInstalledVersion();
    }

    test('no record is first launch; acknowledge then reports false', () async {
      final service = serviceWithVersion(() => '1.0.2');

      expect(await service.isFirstLaunchAfterUpdate(), isTrue);
      expect(await service.currentInstalledVersion(), '1.0.2');

      await service.acknowledgeInstalledVersion();

      expect(await Preferences.getLastSeenInstalledVersion(), '1.0.2');
      expect(await service.isFirstLaunchAfterUpdate(), isFalse);
    });

    test('version change from 1.0.2 to 1.0.3 is first launch again', () async {
      var version = '1.0.2';
      final service = serviceWithVersion(() => version);

      await service.acknowledgeInstalledVersion();
      expect(await service.isFirstLaunchAfterUpdate(), isFalse);

      version = '1.0.3';
      expect(await service.isFirstLaunchAfterUpdate(), isTrue);
    });

    test(
      'first launch after markServiceStarted consumes prompt and keeps intendedRunning',
      () async {
        await UnexpectedStopPreferences.markServiceStarted();
        final service = serviceWithVersion(() => '1.0.3');

        await runFirstLaunchHooks(service);

        expect(
          await UnexpectedStopPreferences.getPromptConsumedStartId(),
          await UnexpectedStopPreferences.getLastStartId(),
        );
        expect(await UnexpectedStopPreferences.getIntendedRunning(), isTrue);
      },
    );

    test('same version launch does not consume prompt again', () async {
      await UnexpectedStopPreferences.markServiceStarted();
      final service = serviceWithVersion(() => '1.0.3');

      await runFirstLaunchHooks(service);
      final consumedStartId =
          await UnexpectedStopPreferences.getPromptConsumedStartId();
      expect(consumedStartId, isNotNull);

      await UnexpectedStopPreferences.setLastStartId(consumedStartId! + 1);

      await runFirstLaunchHooks(service);

      expect(
        await UnexpectedStopPreferences.getPromptConsumedStartId(),
        consumedStartId,
      );
      expect(await service.isFirstLaunchAfterUpdate(), isFalse);
    });

    test(
      'empty version is not first launch, does not write or consume',
      () async {
        await UnexpectedStopPreferences.markServiceStarted();
        final service = serviceWithVersion(() => '');

        expect(await service.isFirstLaunchAfterUpdate(), isFalse);
        await runFirstLaunchHooks(service);
        await service.acknowledgeInstalledVersion();

        expect(await Preferences.getLastSeenInstalledVersion(), isNull);
        expect(
          await UnexpectedStopPreferences.getPromptConsumedStartId(),
          isNull,
        );
        expect(await UnexpectedStopPreferences.getIntendedRunning(), isTrue);
      },
    );
  });

  group('AppUpdateService.isApkFileName', () {
    test('matches apk extension case-insensitively', () {
      expect(AppUpdateService.isApkFileName('bilirec-release.apk'), isTrue);
      expect(AppUpdateService.isApkFileName('update.APK'), isTrue);
      expect(AppUpdateService.isApkFileName('notes.txt'), isFalse);
    });
  });

  group('AppUpdateService.cleanupApkFilesInDirectory', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bilirec_apk_cleanup_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deletes all apk files and keeps other files', () async {
      final apkOne = File('${tempDir.path}/release.apk');
      final apkTwo = File('${tempDir.path}/bilirec-update-123.apk');
      final keepFile = File('${tempDir.path}/state.json');
      await apkOne.writeAsString('apk-one');
      await apkTwo.writeAsString('apk-two');
      await keepFile.writeAsString('{}');

      await AppUpdateService.cleanupApkFilesInDirectory(tempDir);

      expect(await apkOne.exists(), isFalse);
      expect(await apkTwo.exists(), isFalse);
      expect(await keepFile.exists(), isTrue);
    });

    test('completes when directory does not exist', () async {
      final missingDir = Directory('${tempDir.path}/missing');
      await expectLater(
        AppUpdateService.cleanupApkFilesInDirectory(missingDir),
        completes,
      );
    });
  });
}
