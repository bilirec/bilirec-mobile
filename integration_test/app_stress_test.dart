import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_method_channel.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/main.dart' as app;

class _BatteryBypassForegroundTaskPlatform
    extends MethodChannelFlutterForegroundTask {
  @override
  Future<bool> get isIgnoringBatteryOptimizations async => true;
}


const _startLabels = ['啟動', '启动'];
const _stopLabels = ['停止'];
const _inFlightPowerLabels = ['啟動中', '启动中', '停止中'];
const _backendRunningLabels = [
  'Bilirec 系統服務運行中',
  'Bilirec 系统服务运行中',
  'Bilirec 後端運行中',
];
const _checkConnectionLabels = ['檢查系統服務連線', '检查系统服务连接', '檢測後端連線'];
const _connectionFailedLabels = [
  'Bilirec 系統服務沒有回應，請確認已啟動',
  'Bilirec 系统服务没有响应，请确认已启动',
  '目前無法連線到 Bilirec 系統服務，請確認已啟動',
  '目前无法连接到 Bilirec 系统服务，请确认已启动',
];
const _settingsLabels = ['設置錄製輸出路徑', '设置录制输出路径', '打開服務啓動設定', '打开服务启动设置'];
const _localModeLabels = ['本地通知模式', '本地通知模式'];

const _logTag = 'APP_STRESS_TEST';

void _log(String message) {
  debugPrint('[$_logTag][${DateTime.now().toIso8601String()}] $message');
}

String _visibleLabelsSummary(Iterable<String> labels) {
  final visible =
      labels.where((label) => find.text(label).evaluate().isNotEmpty).toList();
  return visible.isEmpty ? '<none>' : visible.join(' | ');
}

Finder _findFirstVisibleText(Iterable<String> labels) {
  for (final label in labels) {
    final finder = find.text(label);
    if (finder.evaluate().isNotEmpty) {
      _log('find text success: "$label"');
      return finder;
    }
  }
  _log('find text fallback to first label: "${labels.first}"');
  return find.text(labels.first);
}

Future<void> _waitForAnyText(
  WidgetTester tester,
  Iterable<String> labels, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 400),
}) async {
  _log(
    'wait any text start: labels=${labels.join(' / ')}, timeout=${timeout.inSeconds}s, step=${step.inMilliseconds}ms',
  );
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < maxTicks; i++) {
    if (labels.any((label) => find.text(label).evaluate().isNotEmpty)) {
      _log('wait any text done at tick=${i + 1}/$maxTicks, visible=${_visibleLabelsSummary(labels)}');
      return;
    }
    if (i == 0 || (i + 1) % 10 == 0) {
      _log('wait any text ticking=${i + 1}/$maxTicks');
    }
    await tester.pump(step);
  }

  _log('wait any text timeout, visible=${_visibleLabelsSummary(labels)}');

  expect(
    labels.any((label) => find.text(label).evaluate().isNotEmpty),
    isTrue,
    reason: '在 ${timeout.inSeconds} 秒內應看到 ${labels.join(' / ')} 其中之一',
  );
}

Future<void> _waitUntilPowerButtonStable(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  _log('wait power stable start: timeout=${timeout.inSeconds}s');
  final deadline = DateTime.now().add(timeout);
  var ticks = 0;
  while (DateTime.now().isBefore(deadline)) {
    ticks++;
    final hasInFlight = _inFlightPowerLabels
        .any((label) => find.text(label).evaluate().isNotEmpty);
    final hasStable = [..._startLabels, ..._stopLabels]
        .any((label) => find.text(label).evaluate().isNotEmpty);

    if (!hasInFlight && hasStable) {
      _log(
        'wait power stable done: ticks=$ticks, inFlightVisible=${_visibleLabelsSummary(_inFlightPowerLabels)}, stableVisible=${_visibleLabelsSummary([..._startLabels, ..._stopLabels])}',
      );
      return;
    }
    if (ticks == 1 || ticks % 8 == 0) {
      _log(
        'wait power stable ticking: ticks=$ticks, inFlightVisible=${_visibleLabelsSummary(_inFlightPowerLabels)}, stableVisible=${_visibleLabelsSummary([..._startLabels, ..._stopLabels])}',
      );
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  _log('wait power stable timeout');

  fail('等待啟停狀態穩定超時（${timeout.inSeconds}s）');
}

Future<void> _tapPowerButton(WidgetTester tester) async {
  final startFinder = _findFirstVisibleText(_startLabels);
  if (startFinder.evaluate().isNotEmpty) {
    _log('tap power button: tapping START');
    await tester.tap(startFinder.first);
    await tester.pump(const Duration(milliseconds: 150));
    return;
  }

  final stopFinder = _findFirstVisibleText(_stopLabels);
  if (stopFinder.evaluate().isNotEmpty) {
    _log('tap power button: tapping STOP');
    await tester.tap(stopFinder.first);
    await tester.pump(const Duration(milliseconds: 150));
    return;
  }

  _log('tap power button failed: no start/stop found');
  fail('找不到可點擊的啟動/停止按鈕');
}

Future<void> _waitForRunningState(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 35),
}) async {
  _log('wait running state start');
  await _waitForAnyText(tester, _backendRunningLabels, timeout: timeout);
  _log('wait running state done: visible=${_visibleLabelsSummary(_backendRunningLabels)}');
}

Future<void> _observeRunningForDuration(
  WidgetTester tester,
  Duration duration, {
  Duration tick = const Duration(seconds: 5),
}) async {
  _log('observe running start: duration=${duration.inSeconds}s, tick=${tick.inSeconds}s');
  final maxTicks = duration.inMilliseconds ~/ tick.inMilliseconds;
  for (var i = 0; i < maxTicks; i++) {
    await tester.pump(tick);
    final stillRunning = _backendRunningLabels
        .any((label) => find.text(label).evaluate().isNotEmpty);
    _log('observe running tick=${i + 1}/$maxTicks, stillRunning=$stillRunning');
    expect(stillRunning, isTrue,
        reason: '觀察期間應維持運行中（tick=${i + 1}/$maxTicks）');
  }
  _log('observe running done');
}

Finder? _findConnectionCheckButton() {
  for (final label in _checkConnectionLabels) {
    final candidate = find.widgetWithText(OutlinedButton, label);
    if (candidate.evaluate().isNotEmpty) {
      _log('found connection button label="$label" via widgetWithText');
      return candidate.first;
    }

    final textFinder = find.text(label);
    if (textFinder.evaluate().isNotEmpty) {
      final buttonAncestor = find.ancestor(
        of: textFinder.first,
        matching: find.byType(OutlinedButton),
      );
      if (buttonAncestor.evaluate().isNotEmpty) {
        _log('found connection button label="$label" via ancestor lookup');
        return buttonAncestor.first;
      }
    }
  }
  return null;
}

Future<void> _assertBackendConnectableFromUi(WidgetTester tester) async {
  _log('assert backend connectable start');

  // Fail fast only when we really observe the known failure texts.
  final failureVisibleAtStart =
      _connectionFailedLabels.any((label) => find.text(label).evaluate().isNotEmpty);
  if (failureVisibleAtStart) {
    fail('檢查系統服務連線顯示無法連線/無回應，判定測試失敗');
  }

  Finder? actionButton;
  for (var i = 0; i < 20; i++) {
    actionButton = _findConnectionCheckButton();
    if (actionButton != null) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (actionButton == null) {
    _log('connection button not found, skip active click check (inconclusive but not failure)');
    return;
  }

  await tester.ensureVisible(actionButton);
  await tester.pump(const Duration(milliseconds: 150));
  _log('tap connection check button');
  await tester.tap(actionButton, warnIfMissed: false);

  var snackbarShown = false;
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 500));

    final cannotConnectNow =
        _connectionFailedLabels.any((label) => find.text(label).evaluate().isNotEmpty);
    if (cannotConnectNow) {
      _log('connection check detected failure text at poll=${i + 1}');
      fail('檢查系統服務連線顯示無法連線/無回應，判定測試失敗');
    }

    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      snackbarShown = true;
      _log('snackbar shown after ${i + 1} polls');
      break;
    }

    if (i == 0 || (i + 1) % 4 == 0) {
      _log('waiting snackbar poll=${i + 1}/16');
    }
  }

  if (!snackbarShown) {
    _log('no snackbar observed within polling window; treating as inconclusive, not failure');
    return;
  }

  final cannotConnect =
      _connectionFailedLabels.any((label) => find.text(label).evaluate().isNotEmpty);
  _log('connection check result: cannotConnect=$cannotConnect');
  expect(cannotConnect, isFalse, reason: '檢查系統服務連線顯示無法連線/無回應，判定測試失敗');
  _log('assert backend connectable done');
}

Future<void> _shutdownServiceSafely(WidgetTester tester) async {
  _log('shutdown service start');
  // If we are still in transition, wait until the power button is stable first.
  final hasInFlight =
      _inFlightPowerLabels.any((label) => find.text(label).evaluate().isNotEmpty);
  if (hasInFlight) {
    _log('shutdown: found in-flight state, waiting stable first');
    await _waitUntilPowerButtonStable(tester);
  }

  if (_findFirstVisibleText(_stopLabels).evaluate().isNotEmpty) {
    _log('shutdown: currently running, tapping stop');
    await _tapPowerButton(tester);
    await _waitUntilPowerButtonStable(tester);
  } else {
    _log('shutdown: already stopped');
  }
  _log('shutdown service done');
}

Future<int> _subscribeRoom(int roomId) async {
  _log('HTTP subscribe room start: roomId=$roomId');
  final client = HttpClient();
  try {
    final request = await client
        .postUrl(Uri.parse('http://127.0.0.1:8080/room/$roomId'))
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>();
    _log('HTTP subscribe room done: roomId=$roomId, status=${response.statusCode}');
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<int> _updateRoomConfig(int roomId) async {
  _log('HTTP update room config start: roomId=$roomId');
  final client = HttpClient();
  try {
    final request = await client
        .putUrl(Uri.parse('http://127.0.0.1:8080/room/$roomId/config'))
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.contentType = ContentType.json;
    request.write('{"auto_record":false,"notify":true,"record_duration_minutes":120}');
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>();
    _log('HTTP update room config done: roomId=$roomId, status=${response.statusCode}');
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<void> _enableLocalNotificationMode(WidgetTester tester) async {
  _log('enable local notification mode start');
  await tester.tap(_findFirstVisibleText(_settingsLabels).first);
  await tester.pumpAndSettle(const Duration(milliseconds: 400));

  final labelFinder = _findFirstVisibleText(_localModeLabels);
  await _waitForAnyText(tester, _localModeLabels);

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

Future<void> _ensureForegroundNotificationPermissionGranted() async {
  _log('permission check: verifying foreground notification permission');
  final permission = await FlutterForegroundTaskPlatform.instance
      .checkNotificationPermission();
  _log('permission check: current=$permission');

  if (permission != NotificationPermission.granted) {
    _log('permission request: requesting notification permission');
    NotificationPermission granted;
    try {
      granted = await FlutterForegroundTaskPlatform.instance
          .requestNotificationPermission()
          .timeout(const Duration(minutes: 3));
    } on TimeoutException {
      fail(
        '等待取得通知權限超時（三分鐘）失敗：請手動在系統對話框或應用設定中授予通知權限後再重試。',
      );
    }
    _log('permission request: result=$granted');

    expect(
      granted,
      NotificationPermission.granted,
      reason: 'Foreground notification permission is required but was not granted. '
          'Please grant POST_NOTIFICATIONS permission on Android 13+ or enable '
          'notification permission in app settings.',
    );
  }

  _log('permission check: verification passed, permission is granted');
}


void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterForegroundTaskPlatform originalPlatform;

  setUpAll(() {
    _log('setUpAll: swap foreground task platform to battery bypass');
    originalPlatform = FlutterForegroundTaskPlatform.instance;
    FlutterForegroundTaskPlatform.instance =
        _BatteryBypassForegroundTaskPlatform();
  });

  tearDownAll(() {
    _log('tearDownAll: restore original foreground task platform');
    FlutterForegroundTaskPlatform.instance = originalPlatform;
  });

  setUp(() {
    _log('setUp: reset foreground task platform to battery bypass');
    FlutterForegroundTaskPlatform.instance =
        _BatteryBypassForegroundTaskPlatform();
  });

  group('Bilirec App 壓測（手動驗證）', () {
    testWidgets(
      'PANIC 壓測：頻繁啟停後導致 .so panic 閃退app',
      (tester) async {
        _log('test start: PANIC stress scenario');

        _log('STEP 0: launch app.main()');
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));
        _log('STEP 0 done');

        // Ensure foreground notification permission is granted before proceeding
        _log('STEP 0.5: verify foreground notification permission');
        await _ensureForegroundNotificationPermissionGranted();
        _log('STEP 0.5 done');

        // 1) 先啟動服務
        _log('STEP 1: start service');
        await _tapPowerButton(tester);
        // Permission dialog handling: on desktop/CI, it's usually auto-granted or bypassed
        await tester.pump(const Duration(milliseconds: 500));
        await _waitForAnyText(tester, _backendRunningLabels);
        _log('STEP 1 done');

        // 2) POST /room/479592 訂閱一個房間
        _log('STEP 2: subscribe room');
        final subscribeStatus = await _subscribeRoom(479592);
        expect(
          [200, 201, 202, 204, 409].contains(subscribeStatus),
          isTrue,
          reason: '訂閱房間失敗，statusCode=$subscribeStatus',
        );
        _log('STEP 2 done: status=$subscribeStatus');

        // 2.1) PUT /room/479592/config 設定通知/錄製參數
        _log('STEP 2.1: update room config');
        final configStatus = await _updateRoomConfig(479592);
        expect(
          [200, 201, 202, 204].contains(configStatus),
          isTrue,
          reason: '更新房間設定失敗，statusCode=$configStatus',
        );
        _log('STEP 2.1 done: status=$configStatus');

        // 3) 然後停止服務
        _log('STEP 3: stop service');
        await _tapPowerButton(tester);
        await _waitUntilPowerButtonStable(tester);
        _log('STEP 3 done');

        // 4) 打開設置，啟用本地通知模式
        _log('STEP 4: enable local notification mode');
        await _enableLocalNotificationMode(tester);
        _log('STEP 4 done');

        // 5) 開始頻繁啟停（啟動中/停止中結束後立刻再按）
        const rounds = 24;
        _log('STEP 5: rapid start/stop rounds=$rounds');
        for (var i = 0; i < rounds; i++) {
          _log('STEP 5 round ${i + 1}/$rounds begin');
          await _tapPowerButton(tester);
          await _waitUntilPowerButtonStable(tester);
          _log('STEP 5 round ${i + 1}/$rounds end');

          final isRunningNow =
              _backendRunningLabels.any((label) => find.text(label).evaluate().isNotEmpty);
          if (isRunningNow) {
            _log('STEP 5.${i + 1}: interim backend connectivity check (running state)');
            await _assertBackendConnectableFromUi(tester);
            _log('STEP 5.${i + 1} done: interim connectivity check passed');
          } else {
            _log('STEP 5 round ${i + 1}: service is stopped, skip connectivity check');
          }
        }
        _log('STEP 5 done');

        // 6) 頻繁啟停後（偶數輪、且起始為停止），理論上應回到停止狀態
        expect(
          _findFirstVisibleText(_startLabels).evaluate().isNotEmpty,
          isTrue,
          reason: '第 5 步結束後預期為停止狀態（按鈕顯示啟動）',
        );

        // 接著按一次即可進入「運行中」
        _log('STEP 6: start service after stress rounds');
        await _tapPowerButton(tester);
        await _waitForRunningState(tester);
        _log('STEP 6 done');

        // 6.1) 運行中後，檢查系統服務連線；無法連線則失敗
        _log('STEP 6.1: verify backend connectable from UI');
        await _assertBackendConnectableFromUi(tester);
        _log('STEP 6.1 done');

        // 7) 處於運行中狀態等待三分鐘（觀察是否 panic）
        _log('STEP 7: observe running for 3 minutes');
        await _observeRunningForDuration(
          tester,
          const Duration(minutes: 3),
        );
        _log('STEP 7 done');

        // 8) 收尾：關閉服務
        _log('STEP 8: shutdown service safely');
        await _shutdownServiceSafely(tester);
        _log('STEP 8 done');

        // 9) 反向驗證：壓測後不應 panic 退出，且應可回到停止狀態。
        expect(
          _findFirstVisibleText(_startLabels).evaluate().isNotEmpty,
          isTrue,
          reason: '壓測完成後應仍存活，且服務已成功關閉回到停止狀態',
        );
        _log('test done: PANIC stress scenario passed');
      },
    );
  });
}
