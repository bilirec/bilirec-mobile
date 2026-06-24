import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/api_helper.dart';
import 'helpers/l10n_helper.dart';
import 'helpers/test_helper.dart';
import 'helpers/ui_helper.dart';

final _startLabels = labelsForKey('start');
final _stopLabels = labelsForKey('stop');
final _inFlightPowerLabels = labelsForKeys(['startingShort', 'stoppingShort']);
final _backendRunningLabels = labelsForKey('backendRunning');
final _checkConnectionLabels = labelsForKey('checkBackendConnection');
final _connectionFailedLabels =
    labelsForKeys(['backendNoResponseHint', 'backendCannotConnect']);
final _settingsLabels = labelsForKey('settings');
final _localModeLabels = labelsForKey('ssePushSwitchTitle');

const _logTag = 'SERVICE_TOGGLE_STRESS_TEST';

void _log(String message) => testLog(_logTag, message);

Future<void> _waitForRunningState(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 35),
}) async {
  _log('wait running state start');
  await waitForAnyText(
    tester,
    _backendRunningLabels,
    timeout: timeout,
    logTag: _logTag,
    waitMode: WaitMode.realtime,
  );
  _log('wait running state done');
}

Future<void> _observeRunningForDuration(
  WidgetTester tester,
  Duration duration, {
  Duration tick = const Duration(seconds: 5),
}) async {
  _log(
      'observe running start: duration=${duration.inSeconds}s, tick=${tick.inSeconds}s');
  final maxTicks = duration.inMilliseconds ~/ tick.inMilliseconds;
  for (var i = 0; i < maxTicks; i++) {
    await Future<void>.delayed(tick);
    await tester.pump();
    final stillRunning = isAnyLabelVisible(_backendRunningLabels);
    _log('observe running tick=${i + 1}/$maxTicks, stillRunning=$stillRunning');
    expect(stillRunning, isTrue, reason: '觀察期間應維持運行中（tick=${i + 1}/$maxTicks）');
  }
  _log('observe running done');
}

Future<void> _enableLocalNotificationMode(WidgetTester tester) async {
  _log('enable local notification mode start');
  await tester
      .tap(findFirstVisibleText(_settingsLabels, logTag: _logTag).first);
  await tester.pumpAndSettle(const Duration(milliseconds: 400));

  final labelFinder = findFirstVisibleText(_localModeLabels, logTag: _logTag);
  await waitForAnyText(tester, _localModeLabels, logTag: _logTag);

  final switchFinder = find.descendant(
    of: find.ancestor(of: labelFinder, matching: find.byType(Row)).first,
    matching: find.byType(Switch),
  );

  expect(switchFinder, findsOneWidget, reason: '應找到本地通知模式開關');
  final current = tester.widget<Switch>(switchFinder);
  _log('local notification mode current value=${current.value}');
  if (!current.value) {
    _log('local notification mode toggling ON');
    await tester.tap(switchFinder);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  } else {
    _log('local notification mode already ON');
  }

  // Prefer gesture close to match real user behavior.
  await tester.fling(
    find.byType(SettingsDrawerSheet),
    const Offset(0, 700),
    1400,
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 300));

  final sheetFinder = find.byType(SettingsDrawerSheet);
  if (sheetFinder.evaluate().isNotEmpty) {
    final sheetContext = tester.element(sheetFinder.first);
    Navigator.of(sheetContext).pop();
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  _log('enable local notification mode done');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterForegroundTaskPlatform originalPlatform;

  setUpAll(() {
    _log('setUpAll: swap foreground task platform to battery bypass');
    originalPlatform = FlutterForegroundTaskPlatform.instance;
    FlutterForegroundTaskPlatform.instance =
        BatteryBypassForegroundTaskPlatform();
  });

  tearDownAll(() {
    _log('tearDownAll: restore original foreground task platform');
    FlutterForegroundTaskPlatform.instance = originalPlatform;
  });

  setUp(() async {
    await resetTestOutputDir();
    _log('setUp: reset foreground task platform to battery bypass');
    FlutterForegroundTaskPlatform.instance =
        BatteryBypassForegroundTaskPlatform();
  });

  group('Bilirec 服務頻繁啟停壓測', () {
    testWidgets(
      '服務頻繁啟停壓測：避免 .so panic 導致閃退',
      (tester) async {
        try {
          _log('test start: PANIC stress scenario');

          _log('STEP 0: launch app.main()');
          app.main();
          await waitForAnyText(
            tester,
            _startLabels,
            timeout: const Duration(seconds: 30),
            logTag: _logTag,
          );
          _log('STEP 0 done');

          // Ensure foreground notification permission is granted before proceeding
          _log('STEP 0.5: verify foreground notification permission');
          await ensureForegroundNotificationPermissionGranted(logTag: _logTag);

          // 1) 先啟動服務
          _log('STEP 1: start service');
          await tapPowerButton(
            tester,
            startLabels: _startLabels,
            stopLabels: _stopLabels,
            logTag: _logTag,
          );
          // Permission dialog handling: on desktop/CI, it's usually auto-granted or bypassed
          await tester.pump(const Duration(milliseconds: 500));
          await waitForAnyText(
            tester,
            _backendRunningLabels,
            logTag: _logTag,
            waitMode: WaitMode.realtime,
          );
          _log('STEP 1 done');

          // 2) POST /room/479592 訂閱一個房間
          _log('STEP 2: subscribe room');
          final subscribeStatus = await subscribeRoom(479592);
          expect(
            [200, 201, 202, 204, 409].contains(subscribeStatus),
            isTrue,
            reason: '訂閱房間失敗，statusCode=$subscribeStatus',
          );
          _log('STEP 2 done: status=$subscribeStatus');

          // 2.1) PUT /room/479592/config 設定通知/錄製參數
          _log('STEP 2.1: update room config');
          final configStatus = await updateRoomConfig(479592);
          expect(
            [200, 201, 202, 204].contains(configStatus),
            isTrue,
            reason: '更新房間設定失敗，statusCode=$configStatus',
          );
          _log('STEP 2.1 done: status=$configStatus');

          // 3) 然後停止服務
          _log('STEP 3: stop service');
          await tapPowerButton(
            tester,
            startLabels: _startLabels,
            stopLabels: _stopLabels,
            logTag: _logTag,
          );
          await waitUntilPowerButtonStable(
            tester,
            inFlightLabels: _inFlightPowerLabels,
            startLabels: _startLabels,
            stopLabels: _stopLabels,
            logTag: _logTag,
            waitMode: WaitMode.realtime,
          );
          _log('STEP 3 done');

          // 4) 打開設置，啟用本地通知模式
          _log('STEP 4: enable local notification mode');
          await _enableLocalNotificationMode(tester);
          _log('STEP 4 done');

          // 5) 開始頻繁啟停（啟動中/停止中結束後立刻再按）
          final rounds = isCiEnv() ? 24 : 12;
          _log('STEP 5: rapid start/stop rounds=$rounds');
          for (var i = 0; i < rounds; i++) {
            _log('STEP 5 round ${i + 1}/$rounds begin');
            await tapPowerButton(
              tester,
              startLabels: _startLabels,
              stopLabels: _stopLabels,
              logTag: _logTag,
            );
            await waitUntilPowerButtonStable(
              tester,
              inFlightLabels: _inFlightPowerLabels,
              startLabels: _startLabels,
              stopLabels: _stopLabels,
              logTag: _logTag,
              waitMode: WaitMode.realtime,
            );
            _log('STEP 5 round ${i + 1}/$rounds end');

            final isRunningNow = isAnyLabelVisible(_backendRunningLabels);
            if (isRunningNow) {
              _log(
                  'STEP 5.${i + 1}: interim backend connectivity check (running state)');
              await assertBackendConnectableFromUi(
                tester,
                checkConnectionLabels: _checkConnectionLabels,
                connectionFailedLabels: _connectionFailedLabels,
                logTag: _logTag,
              );
              _log('STEP 5.${i + 1} done: interim connectivity check passed');
            } else {
              _log(
                  'STEP 5 round ${i + 1}: service is stopped, skip connectivity check');
            }
          }
          _log('STEP 5 done');

          // 6) 頻繁啟停後（偶數輪、且起始為停止），理論上應回到停止狀態
          expect(
            findFirstVisibleText(_startLabels, logTag: _logTag)
                .evaluate()
                .isNotEmpty,
            isTrue,
            reason: '第 5 步結束後預期為停止狀態（按鈕顯示啟動）',
          );

          // 接著按一次即可進入「運行中」
          _log('STEP 6: start service after stress rounds');
          await tapPowerButton(
            tester,
            startLabels: _startLabels,
            stopLabels: _stopLabels,
            logTag: _logTag,
          );
          await _waitForRunningState(tester);
          _log('STEP 6 done');

          // 6.1) 運行中後，檢查系統服務連線；無法連線則失敗
          _log('STEP 6.1: verify backend connectable from UI');
          await assertBackendConnectableFromUi(
            tester,
            checkConnectionLabels: _checkConnectionLabels,
            connectionFailedLabels: _connectionFailedLabels,
            logTag: _logTag,
          );
          _log('STEP 6.1 done');

          // 7) 處於運行中狀態等待3/15分鐘（觀察是否 panic）
          final ci = isCiEnv();
          _log('STEP 7: observe running for ${ci ? 15 : 3} minutes');
          await _observeRunningForDuration(
            tester,
            ci ? const Duration(minutes: 15) : const Duration(minutes: 3),
          );
          _log('STEP 7 done');

          // 8) 收尾：關閉服務
          _log('STEP 8: shutdown service safely');
          await shutdownServiceSafely(
            tester,
            inFlightLabels: _inFlightPowerLabels,
            startLabels: _startLabels,
            stopLabels: _stopLabels,
            logTag: _logTag,
          );
          _log('STEP 8 done');

          // 9) 反向驗證：壓測後不應 panic 退出，且應可回到停止狀態。
          expect(
            findFirstVisibleText(_startLabels, logTag: _logTag)
                .evaluate()
                .isNotEmpty,
            isTrue,
            reason: '壓測完成後應仍存活，且服務已成功關閉回到停止狀態',
          );
          _log('test done: PANIC stress scenario passed');
        } catch (e, st) {
          _log('service toggle stress failed: $e');
          _log('$st');
          await printBootstrapLogsIfAny(
            scenario: 'Service toggle stress failed',
            logTag: _logTag,
          );
          rethrow;
        }
      },
      timeout: const Timeout(Duration(minutes: 40)),
    );
  });
}
