import 'package:bilirec/main.dart' as app;
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers/l10n_helper.dart';
import 'helpers/test_helper.dart';
import 'helpers/ui_helper.dart';

final _startLabels = labelsForKey('start');
final _stopLabels = labelsForKey('stop');
final _titleLabels = labelsForKey('controlCenterTitle');
final _settingsLabels = labelsForKey('settings');
final _checkConnectionLabels = labelsForKey('checkBackendConnection');
final _openFrontendLabels = labelsForKey('openFrontend');
final _runningStatusLabels = labelsForKey('backendRunning');
final _inFlightPowerLabels = labelsForKeys(['startingShort', 'stoppingShort']);
final _startingStatusLabels = labelsForKeys([
  'startingService',
  'foregroundStartWaitingCore',
  'startingShort',
]);
final _androidOnlyLabels = labelsForKey('androidOnly');
final _generalSettingsTitleLabels = labelsForKey('generalSettingsTitle');
final _storagePathTitleLabels = labelsForKey('storagePathTitle');
final _changePathLabels = labelsForKey('changePath');
final _ssePushSwitchTitleLabels = labelsForKey('ssePushSwitchTitle');
final _antiSleepTitleLabels = labelsForKey('antiSleepTitle');
final _developerSettingsTitleLabels = labelsForKey('developerSettingsTitle');
final _environmentSettingsTitleLabels = labelsForKey('environmentSettingsTitle');
final _addEnvironmentSettingLabels = labelsForKey('addEnvironmentSetting');
final _savedEnvironmentSettingsTitleLabels =
    labelsForKey('savedEnvironmentSettingsTitle');
final _batteryDialogTitleLabels = labelsForKey('batteryDialogTitle');
final _goToSettingsLabels = labelsForKey('goToSettings');

Future<void> _openSettingsSheet(WidgetTester tester) async {
  final settingsFinder = findFirstVisibleText(_settingsLabels).first;
  await tester.ensureVisible(settingsFinder);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(settingsFinder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _closeSettingsSheet(WidgetTester tester) async {
  final sheetFinder = find.byType(BottomSheet);
  if (sheetFinder.evaluate().isEmpty) {
    return;
  }
  final context = tester.element(sheetFinder.first);
  Navigator.of(context).pop();
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

Future<void> _setRecordingPolicyValues(WidgetTester tester) async {
  final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
  expect(sliders.length, greaterThanOrEqualTo(4), reason: '應至少有 4 個錄製策略滑動條');

  // 順序：時長上限、啟動前可用空間、斷線等待、同時錄製上限。
  sliders[0].onChanged?.call(0);
  sliders[0].onChangeEnd?.call(0);
  await tester.pumpAndSettle();
  sliders[1].onChanged?.call(2);
  sliders[1].onChangeEnd?.call(2);
  await tester.pumpAndSettle();
  sliders[2].onChanged?.call(5);
  sliders[2].onChangeEnd?.call(5);
  await tester.pumpAndSettle();
  sliders[3].onChanged?.call(1);
  sliders[3].onChangeEnd?.call(1);
  await tester.pumpAndSettle();
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  bool didLaunch = false;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    didLaunch = true;
    return true;
  }
}

Future<void> _stopServiceIfRunning(WidgetTester tester) async {
  await shutdownServiceSafely(
    tester,
    inFlightLabels: _inFlightPowerLabels,
    startLabels: _startLabels,
    stopLabels: _stopLabels,
  );
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

  setUp(() {
    FlutterForegroundTaskPlatform.instance =
        PermissionGrantedForegroundTaskPlatform();
  });

  group('Bilirec App 整合測試（模擬器可視化）', () {
    testWidgets('1. 首頁標題與初始狀態正確顯示', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(findFirstVisibleText(_titleLabels), findsOneWidget);
      expect(findFirstVisibleText(_startLabels), findsOneWidget);
      expect(findFirstVisibleText(_settingsLabels), findsOneWidget);

      // 行為按鈕只會在服務運行中顯示。
      for (final label in _checkConnectionLabels) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('2. 可開啟設定抽屜並顯示最新設定項目', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(findFirstVisibleText(_settingsLabels));
      await tester.pumpAndSettle();

      expect(findFirstVisibleText(_generalSettingsTitleLabels), findsOneWidget);
      expect(findFirstVisibleText(_storagePathTitleLabels), findsOneWidget);
      expect(findFirstVisibleText(_changePathLabels), findsOneWidget);
      expect(findFirstVisibleText(_ssePushSwitchTitleLabels), findsOneWidget);
      expect(findFirstVisibleText(_antiSleepTitleLabels), findsOneWidget);
      expect(findFirstVisibleText(_developerSettingsTitleLabels), findsOneWidget);
      expect(findFirstVisibleText(_environmentSettingsTitleLabels), findsOneWidget);
      expect(findFirstVisibleText(_addEnvironmentSettingLabels), findsOneWidget);
      expect(
        findFirstVisibleText(_savedEnvironmentSettingsTitleLabels),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('3. 啟動服務後顯示動作區並可檢查連線', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(findFirstVisibleText(_startLabels));
      await tester.pump(const Duration(milliseconds: 500));

      final canContinue = !isAnyLabelVisible(_androidOnlyLabels);
      if (!canContinue) {
        markTestSkipped('目前只支援 Android，跳過此整合測試案例');
        return;
      }

      await waitForAnyText(
        tester,
        [..._startingStatusLabels, ..._runningStatusLabels],
        timeout: const Duration(seconds: 25),
      );
      await waitForAnyText(tester, _runningStatusLabels,
          timeout: const Duration(seconds: 35));

      expect(findFirstVisibleText(_openFrontendLabels), findsOneWidget);
      expect(findFirstVisibleText(_checkConnectionLabels), findsOneWidget);

      await tapButtonByLabels(
        tester,
        buttonType: OutlinedButton,
        labels: _checkConnectionLabels,
      );

      var toastShown = false;
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(AppToast).evaluate().isNotEmpty) {
          toastShown = true;
          break;
        }
      }

      expect(toastShown, isTrue, reason: '應顯示後端連線檢測結果 toast');

      await _stopServiceIfRunning(tester);
    });

    testWidgets('4. 電池無限制 dialog 在模擬器上出現（Android 環境）', (tester) async {
      FlutterForegroundTaskPlatform.instance =
          BatteryDialogForegroundTaskPlatform();
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance =
            PermissionGrantedForegroundTaskPlatform();
      });

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(findFirstVisibleText(_batteryDialogTitleLabels), findsOneWidget);
      expect(findFirstVisibleText(_goToSettingsLabels), findsOneWidget);
      // 不真的送出，避免跳出測試 App
    });

    testWidgets('5. 全流程：啟動→測連線→打開前端', (tester) async {
      final originalUrlLauncher = UrlLauncherPlatform.instance;
      final fakeUrlLauncher = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakeUrlLauncher;
      addTearDown(() {
        UrlLauncherPlatform.instance = originalUrlLauncher;
      });

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(findFirstVisibleText(_titleLabels), findsOneWidget);
      expect(findFirstVisibleText(_startLabels), findsOneWidget);

      await tester.tap(findFirstVisibleText(_startLabels));
      await tester.pump(const Duration(milliseconds: 500));
      await waitForAnyText(tester, _runningStatusLabels,
          timeout: const Duration(seconds: 35));

      await tapButtonByLabels(
        tester,
        buttonType: OutlinedButton,
        labels: _checkConnectionLabels,
      );
      var toastShown = false;
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(AppToast).evaluate().isNotEmpty) {
          toastShown = true;
          break;
        }
      }
      expect(toastShown, isTrue, reason: '全流程中應顯示連線檢測結果 toast');

      await tapButtonByLabels(
        tester,
        buttonType: FilledButton,
        labels: _openFrontendLabels,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(fakeUrlLauncher.didLaunch, isTrue, reason: '全流程中應觸發啟動前端跳轉');

      await _stopServiceIfRunning(tester);
    });

    testWidgets('6. 錄製策略設定可持久化並在重開後回填', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await _openSettingsSheet(tester);

      final initialSliders =
          tester.widgetList<Slider>(find.byType(Slider)).toList(growable: false);
      expect(initialSliders.length, greaterThanOrEqualTo(4));
      expect(initialSliders[0].value, 5);
      expect(initialSliders[1].value, 1);
      expect(initialSliders[2].value, 1);
      expect(initialSliders[3].value, 0);

      await _setRecordingPolicyValues(tester);

      final envAfterUpdate = await Preferences.getEnvironmentSettings();
      expect(envAfterUpdate['MAX_RECORDING_HOURS'], '0');
      expect(
        envAfterUpdate['MIN_DISK_SPACE_BYTES'],
        '${10 * 1024 * 1024 * 1024}',
      );
      expect(envAfterUpdate['MAX_RETRY_MINUTES'], '30');
      expect(envAfterUpdate['MAX_CONCURRENT_RECORDINGS'], '4');

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await _openSettingsSheet(tester);
      final slidersAfterRestart =
          tester.widgetList<Slider>(find.byType(Slider)).toList(growable: false);
      expect(slidersAfterRestart.length, greaterThanOrEqualTo(4));
      expect(slidersAfterRestart[0].value, 0);
      expect(slidersAfterRestart[1].value, 2);
      expect(slidersAfterRestart[2].value, 5);
      expect(slidersAfterRestart[3].value, 1);

      await _closeSettingsSheet(tester);

      await tester.tap(findFirstVisibleText(_startLabels));
      await tester.pump(const Duration(milliseconds: 500));

      if (isAnyLabelVisible(_androidOnlyLabels)) {
        markTestSkipped('目前只支援 Android，跳過此整合測試案例');
        return;
      }

      await waitForAnyText(
        tester,
        [..._startingStatusLabels, ..._runningStatusLabels],
        timeout: const Duration(seconds: 25),
      );

      await _stopServiceIfRunning(tester);
    });
  });
}
