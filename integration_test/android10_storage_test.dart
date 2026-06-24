import 'dart:io';

import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/main.dart' as app;
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'helpers/storage_helper.dart';
import 'helpers/file_picker_test_helper.dart';
import 'helpers/l10n_helper.dart';
import 'helpers/test_helper.dart';
import 'helpers/ui_helper.dart';

const _logTag = 'ANDROID10_STORAGE_TEST';

final _startLabels = labelsForKey('start');
final _stopLabels = labelsForKey('stop');
final _inFlightPowerLabels = labelsForKeys(['startingShort', 'stoppingShort']);
final _runningStatusLabels = labelsForKey('backendRunning');
final _settingsLabels = labelsForKey('settings');
final _externalStorageDeniedLabels =
    labelsForKey('externalStoragePermissionDenied');
final _downloadBootstrapLogLabels = labelsForKey('downloadBootstrapLog');
final _downloadBootstrapLogSuccessLabels =
    labelsForKeys(['downloadBootstrapLogSuccess', '匯出至', '导出至']);

Future<void> _waitForHomeReady(WidgetTester tester) async {
  await waitForAnyText(
    tester,
    _startLabels,
    timeout: const Duration(seconds: 30),
    logTag: _logTag,
  );
}

Future<void> _openSettingsSheet(WidgetTester tester) async {
  final settingsFinder = findFirstVisibleText(_settingsLabels).first;
  await tester.ensureVisible(settingsFinder);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(settingsFinder, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
  expect(find.byType(SettingsDrawerSheet), findsOneWidget);
}

Future<void> _startServiceAndWaitRunning(WidgetTester tester) async {
  await tapPowerButton(
    tester,
    startLabels: _startLabels,
    stopLabels: _stopLabels,
    logTag: _logTag,
  );
  await waitForAnyText(
    tester,
    _runningStatusLabels,
    timeout: const Duration(seconds: 60),
    logTag: _logTag,
    waitMode: WaitMode.realtime,
  );
  await waitUntilPowerButtonStable(
    tester,
    inFlightLabels: _inFlightPowerLabels,
    startLabels: _startLabels,
    stopLabels: _stopLabels,
    logTag: _logTag,
    waitMode: WaitMode.realtime,
  );
}

Future<void> _tapDownloadBootstrapLog(WidgetTester tester) async {
  final downloadFinder = findFirstVisibleText(_downloadBootstrapLogLabels);
  final scrollable = find.descendant(
    of: find.byType(SettingsDrawerSheet),
    matching: find.byType(Scrollable),
  );
  if (scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      downloadFinder,
      300,
      scrollable: scrollable.first,
    );
  }
  await tester.ensureVisible(downloadFinder);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(downloadFinder, warnIfMissed: false);
}

Future<File?> _findExportedBootstrapLog(String exportDir) async {
  final dir = Directory(exportDir);
  if (!await dir.exists()) {
    return null;
  }

  final files = <File>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name.startsWith('bootstrap_') && name.endsWith('.log')) {
      files.add(entity);
    }
  }
  if (files.isEmpty) {
    return null;
  }
  files.sort((a, b) => b.path.compareTo(a.path));
  return files.first;
}

Future<bool> _waitForBootstrapLogsInAppSupport({
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory(appSupport.path);
    if (await dir.exists()) {
      final hasLog = await dir
          .list()
          .where((entity) {
            if (entity is! File) return false;
            final name = entity.uri.pathSegments.last;
            return name.startsWith('bootstrap') && name.endsWith('.log');
          })
          .isEmpty
          .then((empty) => !empty);
      if (hasLog) {
        return true;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return false;
}

Future<bool> _skipUnlessAndroid10() async {
  if (!await isAndroid10Only(logTag: _logTag)) {
    markTestSkipped('僅在 Android 10（API 29）執行');
    return false;
  }
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterForegroundTaskPlatform originalPlatform;

  setUpAll(() {
    originalPlatform = FlutterForegroundTaskPlatform.instance;
    FlutterForegroundTaskPlatform.instance =
        PermissionGrantedForegroundTaskPlatform();
  });

  tearDownAll(() {
    FlutterForegroundTaskPlatform.instance = originalPlatform;
  });

  setUp(() async {
    await resetTestOutputDir();
    FlutterForegroundTaskPlatform.instance =
        PermissionGrantedForegroundTaskPlatform();
  });

  tearDown(() async {
    await resetTestOutputDir();
    await resetStorageTestDirs(logTag: _logTag);
  });

  group('Android 10 Storage 整合測試', () {
    testWidgets('Case 1：已授權 + 自訂外部路徑可啟動服務', (tester) async {
      if (!await _skipUnlessAndroid10()) return;

      await ensureLegacyStoragePermissionGranted(logTag: _logTag);

      final outputDir = defaultExternalTestOutputDir();
      await ensureExternalDirExists(outputDir, logTag: _logTag);
      await Preferences.setOutputDir(outputDir);

      app.main();
      await _waitForHomeReady(tester);
      await _startServiceAndWaitRunning(tester);

      expect(
        isAnyLabelVisible(_externalStorageDeniedLabels),
        isFalse,
        reason: '已授權時不應顯示 storage 權限拒絕訊息',
      );

      await shutdownServiceSafely(
        tester,
        inFlightLabels: _inFlightPowerLabels,
        startLabels: _startLabels,
        stopLabels: _stopLabels,
        logTag: _logTag,
      );
    });

    testWidgets('Case 3：啟停服務後可匯出 bootstrap log 至外部路徑', (tester) async {
      if (!await _skipUnlessAndroid10()) return;

      await ensureLegacyStoragePermissionGranted(logTag: _logTag);

      final exportDir = defaultExternalLogExportDir();
      await ensureExternalDirExists(exportDir, logTag: _logTag);

      final mockPicker = MockDirectoryFilePicker(exportDir);
      mockPicker.install();
      addTearDown(mockPicker.restore);

      app.main();
      await _waitForHomeReady(tester);
      await _startServiceAndWaitRunning(tester);

      final hasBootstrapLog = await _waitForBootstrapLogsInAppSupport();
      expect(
        hasBootstrapLog,
        isTrue,
        reason: '啟動服務後應在 app support 產生 bootstrap*.log',
      );

      await shutdownServiceSafely(
        tester,
        inFlightLabels: _inFlightPowerLabels,
        startLabels: _startLabels,
        stopLabels: _stopLabels,
        logTag: _logTag,
      );

      await _openSettingsSheet(tester);
      await _tapDownloadBootstrapLog(tester);

      final toastShown = await waitForCondition(
        tester,
        timeout: const Duration(seconds: 20),
        step: const Duration(milliseconds: 400),
        logTag: _logTag,
        description: 'bootstrap log export success toast',
        waitMode: WaitMode.realtime,
        condition: () {
          if (isAnyLabelVisible(_externalStorageDeniedLabels)) {
            fail('匯出 log 時不應因 storage 權限被拒而失敗');
          }
          return find.byType(AppToast).evaluate().isNotEmpty ||
              isAnyLabelVisible(_downloadBootstrapLogSuccessLabels,
                  contains: true);
        },
      );
      expect(toastShown, isTrue, reason: '應顯示 bootstrap log 匯出成功提示');

      await Future<void>.delayed(const Duration(milliseconds: 500));
      final exported = await _findExportedBootstrapLog(exportDir);
      expect(exported, isNotNull, reason: '外部目錄應產生 bootstrap_*.log');
      expect(exported!.lengthSync(), greaterThan(0), reason: '匯出檔案不應為空');

      final content = await exported.readAsString();
      expect(content.trim().isNotEmpty, isTrue, reason: '匯出檔案應含 log 內容');
    });
  });
}
