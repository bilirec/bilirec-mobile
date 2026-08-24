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
      await service.cleanupDownloadedApks();
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

  group('AppUpdateService.updateApkFileNameForVersion', () {
    test('uses normalized version in filename', () {
      expect(
        AppUpdateService.updateApkFileNameForVersion('v1.0.3+9'),
        'bilirec-update-1.0.3.apk',
      );
    });
  });

  group('AppUpdateService.cleanupOtherVersionedUpdateApks', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'bilirec_apk_stale_cleanup_test',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deletes other versioned update apks and keeps the target', () async {
      final keep = File('${tempDir.path}/bilirec-update-1.0.3.apk');
      final stale = File('${tempDir.path}/bilirec-update-1.0.2.apk');
      final releaseApk = File('${tempDir.path}/bilirec-release.apk');
      final notes = File('${tempDir.path}/notes.txt');
      await keep.writeAsString('keep');
      await stale.writeAsString('stale');
      await releaseApk.writeAsString('release');
      await notes.writeAsString('ok');

      await AppUpdateService.cleanupOtherVersionedUpdateApks(
        tempDir,
        keepFileName: 'bilirec-update-1.0.3.apk',
      );

      expect(await keep.exists(), isTrue);
      expect(await stale.exists(), isFalse);
      expect(await releaseApk.exists(), isTrue);
      expect(await notes.exists(), isTrue);
    });
  });

  group('AppUpdateService.downloadApkToInternalStorage', () {
    late Directory tempDir;
    late HttpServer server;
    var requestCount = 0;
    const apkBytes = [1, 2, 3, 4];
    late String apkUrl;

    AppUpdateService makeService() {
      return AppUpdateService(
        currentAppVersionProvider: () async => '1.0.3',
        temporaryDirectoryProvider: () async => tempDir,
        externalStorageDirectoryProvider: () async => null,
      );
    }

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'bilirec_apk_download_test',
      );
      requestCount = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requestCount++;
        request.response.statusCode = 200;
        request.response.add(apkBytes);
        await request.response.close();
      });
      apkUrl =
          'http://${server.address.host}:${server.port}/bilirec-release.apk';
    });

    tearDown(() async {
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reuses existing versioned apk without HTTP', () async {
      final cached = File('${tempDir.path}/bilirec-update-1.0.3.apk');
      await cached.writeAsBytes(const [9, 9, 9]);

      final path = await makeService().downloadApkToInternalStorage(
        apkUrl,
        version: 'v1.0.3',
      );

      expect(path, cached.path);
      expect(requestCount, 0);
      expect(await cached.readAsBytes(), const [9, 9, 9]);
    });

    test('downloads to versioned filename when missing', () async {
      final path = await makeService().downloadApkToInternalStorage(
        apkUrl,
        version: 'v1.0.3',
      );

      expect(path, '${tempDir.path}/bilirec-update-1.0.3.apk');
      expect(requestCount, 1);
      expect(await File(path!).readAsBytes(), apkBytes);
    });

    test('re-downloads empty versioned file', () async {
      final empty = File('${tempDir.path}/bilirec-update-1.0.3.apk');
      await empty.writeAsBytes(const []);

      final path = await makeService().downloadApkToInternalStorage(
        apkUrl,
        version: '1.0.3',
      );

      expect(path, empty.path);
      expect(requestCount, 1);
      expect(await empty.readAsBytes(), apkBytes);
    });

    test('deletes other versioned update apks when downloading', () async {
      final stale = File('${tempDir.path}/bilirec-update-1.0.2.apk');
      await stale.writeAsString('old');

      await makeService().downloadApkToInternalStorage(
        apkUrl,
        version: '1.0.3',
      );

      expect(await stale.exists(), isFalse);
      expect(
        await File('${tempDir.path}/bilirec-update-1.0.3.apk').exists(),
        isTrue,
      );
    });
  });

  group('first launch apk cleanup vs later launches', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'bilirec_apk_first_launch_cleanup_test',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'first launch cleans apks; same-version start keeps downloaded file',
      () async {
        final leftover = File('${tempDir.path}/bilirec-release.apk');
        await leftover.writeAsString('old');

        final service = AppUpdateService(
          currentAppVersionProvider: () async => '1.0.3',
          temporaryDirectoryProvider: () async => tempDir,
          externalStorageDirectoryProvider: () async => null,
        );

        expect(await service.isFirstLaunchAfterUpdate(), isTrue);
        await AppUpdateService.cleanupApkFilesInDirectory(tempDir);
        await service.acknowledgeInstalledVersion();
        expect(await leftover.exists(), isFalse);

        final downloaded = File('${tempDir.path}/bilirec-update-1.0.4.apk');
        await downloaded.writeAsString('cached-next');

        expect(await service.isFirstLaunchAfterUpdate(), isFalse);
        expect(await downloaded.exists(), isTrue);
      },
    );
  });
}
