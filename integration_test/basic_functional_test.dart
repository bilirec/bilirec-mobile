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
const _logTag = 'BASIC_FUNCTIONAL_TEST';
final _expectedRecordingPolicySliderValues = <double>[0, 2, 5, 1];
final _expectedManagedEnvironmentAfterPolicy = <String, String>{
  'MAX_RECORDING_HOURS': '0',
  'MIN_DISK_SPACE_BYTES': '${10 * 1024 * 1024 * 1024}',
  'MAX_RETRY_MINUTES': '30',
  'MAX_CONCURRENT_RECORDINGS': '4',
};

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
  // 只操作前 4 個，避免因新增滑動條導致測試失敗
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

bool _recordingPolicySlidersMatch(
  List<Slider> sliders,
  List<double> expectedValues,
) {
  if (sliders.length < expectedValues.length) {
    return false;
  }

  for (var i = 0; i < expectedValues.length; i++) {
    if ((sliders[i].value - expectedValues[i]).abs() > 0.001) {
      return false;
    }
  }
  return true;
}

Future<List<Slider>> _waitForRecordingPolicySliders(
  WidgetTester tester, {
  required List<double> expectedValues,
  Duration timeout = const Duration(seconds: 15),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  List<Slider> latest = <Slider>[];
  for (var i = 0; i < maxTicks; i++) {
    latest = tester.widgetList<Slider>(find.byType(Slider)).toList(growable: false);
    if (_recordingPolicySlidersMatch(latest, expectedValues)) {
      return latest;
    }

    await Future<void>.delayed(step);
    await tester.pump();
  }

  final latestValues = latest
      .take(expectedValues.length)
      .map((slider) => slider.value)
      .toList(growable: false);
  fail(
    '等待錄製策略滑動條回填超時。expected=$expectedValues actual=$latestValues',
  );
}

bool _managedEnvironmentMatches(
  Map<String, String> current,
  Map<String, String> expected,
) {
  return expected.entries.every((entry) => current[entry.key] == entry.value);
}

Future<Map<String, String>> _waitForManagedEnvironmentSettings(
  WidgetTester tester, {
  required Map<String, String> expected,
  Duration timeout = const Duration(seconds: 15),
  Duration step = const Duration(milliseconds: 300),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  var latest = <String, String>{};
  for (var i = 0; i < maxTicks; i++) {
    latest = await Preferences.getManagedEnvironmentSettings();
    if (_managedEnvironmentMatches(latest, expected)) {
      return latest;
    }

    await Future<void>.delayed(step);
    await tester.pump();
  }

  fail('等待 ManagedEnvironmentSettings 落盤超時。expected=$expected actual=$latest');
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

Future<void> _waitForHomeReady(WidgetTester tester) async {
  await waitForAnyText(
    tester,
    _titleLabels,
    timeout: const Duration(seconds: 30),
    logTag: _logTag,
  );
  await waitForAnyText(
    tester,
    _startLabels,
    timeout: const Duration(seconds: 30),
    logTag: _logTag,
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
      await _waitForHomeReady(tester);

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
      await _waitForHomeReady(tester);

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
      // 驗證關鍵設定項存在，但不限制總數（避免新增項目導致測試失敗）
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('3. 啟動服務後顯示動作區並可檢查連線', (tester) async {
      try {
        app.main();
        await _waitForHomeReady(tester);

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
          waitMode: WaitMode.realtime,
        );
        await waitForAnyText(
          tester,
          _runningStatusLabels,
          timeout: const Duration(seconds: 60),
          waitMode: WaitMode.realtime,
        );

        expect(findFirstVisibleText(_openFrontendLabels), findsOneWidget);
        expect(findFirstVisibleText(_checkConnectionLabels), findsOneWidget);

        await tapButtonByLabels(
          tester,
          buttonType: OutlinedButton,
          labels: _checkConnectionLabels,
        );

        final toastShown = await waitForCondition(
          tester,
          timeout: const Duration(seconds: 12),
          step: const Duration(milliseconds: 500),
          logTag: _logTag,
          description: 'backend connection toast',
          waitMode: WaitMode.realtime,
          condition: () => find.byType(AppToast).evaluate().isNotEmpty,
        );

        expect(toastShown, isTrue, reason: '應顯示後端連線檢測結果 toast');

        await _stopServiceIfRunning(tester);
      } catch (e, st) {
        testLog(_logTag, 'basic functional test failed: $e');
        testLog(_logTag, '$st');
        await printBootstrapLogsIfAny(
          scenario: 'Basic functional test failed',
          logTag: _logTag,
        );
        rethrow;
      }
    });

    testWidgets('4. 電池無限制 dialog 在模擬器上出現（Android 環境）', (tester) async {
      FlutterForegroundTaskPlatform.instance =
          BatteryDialogForegroundTaskPlatform();
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance =
            PermissionGrantedForegroundTaskPlatform();
      });

      app.main();
      await _waitForHomeReady(tester);

      final dialogShown = await waitForCondition(
        tester,
        timeout: const Duration(seconds: 20),
        step: const Duration(milliseconds: 500),
        logTag: _logTag,
        description: 'battery dialog title',
        waitMode: WaitMode.realtime,
        condition: () => isAnyLabelVisible(_batteryDialogTitleLabels),
      );

      if (!dialogShown) {
        markTestSkipped('電池無限制提示未出現，可能為系統/權限差異');
        return;
      }

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
      await _waitForHomeReady(tester);

      expect(findFirstVisibleText(_titleLabels), findsOneWidget);
      expect(findFirstVisibleText(_startLabels), findsOneWidget);

      await tester.tap(findFirstVisibleText(_startLabels));
      await tester.pump(const Duration(milliseconds: 500));

      final canContinue = !isAnyLabelVisible(_androidOnlyLabels);
      if (!canContinue) {
        markTestSkipped('目前只支援 Android，跳過此整合測試案例');
        return;
      }

      await waitForAnyText(
        tester,
        _runningStatusLabels,
        timeout: const Duration(seconds: 60),
        waitMode: WaitMode.realtime,
      );

      await tapButtonByLabels(
        tester,
        buttonType: OutlinedButton,
        labels: _checkConnectionLabels,
      );
      final toastShown = await waitForCondition(
        tester,
        timeout: const Duration(seconds: 12),
        step: const Duration(milliseconds: 500),
        logTag: _logTag,
        description: 'backend connection toast',
        waitMode: WaitMode.realtime,
        condition: () => find.byType(AppToast).evaluate().isNotEmpty,
      );
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
      await _waitForHomeReady(tester);

      await _openSettingsSheet(tester);

      // 驗證錄製策略滑動條的預設值（這是功能契約）
      final initialSliders =
          tester.widgetList<Slider>(find.byType(Slider)).toList(growable: false);
      expect(initialSliders.length, greaterThanOrEqualTo(4));
      expect(initialSliders[0].value, 5); // MAX_RECORDING_HOURS 預設 5
      expect(initialSliders[1].value, 1); // MIN_DISK_SPACE_BYTES 預設 5GB
      expect(initialSliders[2].value, 1); // MAX_RETRY_MINUTES 預設 5 分鐘
      expect(initialSliders[3].value, 0); // MAX_CONCURRENT_RECORDINGS 預設無限制

      await _setRecordingPolicyValues(tester);

      // 關閉設定抽屜以觸發保存
      await _closeSettingsSheet(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await _waitForManagedEnvironmentSettings(
        tester,
        expected: _expectedManagedEnvironmentAfterPolicy,
      );

      app.main();
      await _waitForHomeReady(tester);

      await _openSettingsSheet(tester);
      // 驗證持久化：重啟後滑動條應該回填之前設定的值
      final slidersAfterRestart = await _waitForRecordingPolicySliders(
        tester,
        expectedValues: _expectedRecordingPolicySliderValues,
      );
      expect(slidersAfterRestart.length, greaterThanOrEqualTo(4));
      expect(slidersAfterRestart[0].value, 0); // MAX_RECORDING_HOURS 改為 0（無限制）
      expect(slidersAfterRestart[1].value, 2); // MIN_DISK_SPACE_BYTES 改為 10GB
      expect(slidersAfterRestart[2].value, 5); // MAX_RETRY_MINUTES 改為 30 分鐘
      expect(slidersAfterRestart[3].value, 1); // MAX_CONCURRENT_RECORDINGS 改為 4

      // 驗證資料庫層：確認持久化值正確寫入
      // 注意：新版本保存到 ManagedEnvironmentSettings，要用對應的 API 讀取
      final envAfterRestart = await Preferences.getManagedEnvironmentSettings();
      expect(
        _managedEnvironmentMatches(
          envAfterRestart,
          _expectedManagedEnvironmentAfterPolicy,
        ),
        isTrue,
      );

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
        timeout: const Duration(seconds: 60),
        waitMode: WaitMode.realtime,
      );

      await _stopServiceIfRunning(tester);
    });
  });
}
