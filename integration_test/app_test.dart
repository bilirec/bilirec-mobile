import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_method_channel.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:bilirec/main.dart' as app;

const _startLabels = ['啟動', '启动'];
const _stopLabels = ['停止'];
const _titleLabels = ['Bilirec 服務控制中心', 'Bilirec 服务控制中心'];
const _settingsLabels = ['打開服務啓動設定', '打开服务启动设置'];
const _checkConnectionLabels = ['檢查系統服務連線', '检查系统服务连接'];
const _openFrontendLabels = ['打開錄製管理程式', '打开录制管理程序'];
const _runningStatusLabels = ['Bilirec 系統服務運行中', 'Bilirec 系统服务运行中'];
const _startingStatusLabels = [
  '正在啟動 Bilirec 系統服務...',
  '正在启动 Bilirec 系统服务...',
  'Bilirec 系統服務已啟動，正在準備中...',
  'Bilirec 系统服务已启动，正在准备中...',
  '啟動中',
  '启动中',
];

class _BatteryBypassForegroundTaskPlatform
    extends MethodChannelFlutterForegroundTask {
  @override
  Future<bool> get isIgnoringBatteryOptimizations async => true;
}

class _PermissionGrantedForegroundTaskPlatform
    extends _BatteryBypassForegroundTaskPlatform {
  @override
  Future<NotificationPermission> checkNotificationPermission() async {
    return NotificationPermission.granted;
  }

  @override
  Future<NotificationPermission> requestNotificationPermission() async {
    return NotificationPermission.granted;
  }
}

class _BatteryDialogForegroundTaskPlatform
    extends MethodChannelFlutterForegroundTask {
  @override
  Future<bool> get isIgnoringBatteryOptimizations async => false;

  @override
  Future<NotificationPermission> checkNotificationPermission() async {
    return NotificationPermission.granted;
  }

  @override
  Future<NotificationPermission> requestNotificationPermission() async {
    return NotificationPermission.granted;
  }
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

Finder _findFirstVisibleText(Iterable<String> labels) {
  for (final label in labels) {
    final finder = find.text(label);
    if (finder.evaluate().isNotEmpty) {
      return finder.first;
    }
  }
  return find.text(labels.first);
}

Future<void> _waitForAnyText(
  WidgetTester tester,
  Iterable<String> labels, {
  Duration timeout = const Duration(minutes: 1),
  Duration step = const Duration(milliseconds: 400),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < maxTicks; i++) {
    if (labels.any((label) => find.text(label).evaluate().isNotEmpty)) {
      return;
    }
    await tester.pump(step);
  }

  expect(
    labels.any((label) => find.text(label).evaluate().isNotEmpty),
    isTrue,
    reason: '在 ${timeout.inSeconds} 秒內應看到 ${labels.join(' / ')} 其中之一',
  );
}

Future<void> _tapActionButton(WidgetTester tester, Iterable<String> labels) async {
  Finder? actionButton;
  for (final label in labels) {
    final candidate = find.widgetWithText(OutlinedButton, label);
    if (candidate.evaluate().isNotEmpty) {
      actionButton = candidate.first;
      break;
    }
  }
  expect(actionButton, isNotNull,
      reason: '應找到按鈕: ${labels.join(' / ')}');
  await tester.ensureVisible(actionButton!);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(actionButton, warnIfMissed: false);
}

Future<void> _tapPrimaryButton(WidgetTester tester, Iterable<String> labels) async {
  Finder? actionButton;
  for (final label in labels) {
    final candidate = find.widgetWithText(FilledButton, label);
    if (candidate.evaluate().isNotEmpty) {
      actionButton = candidate.first;
      break;
    }
  }
  expect(actionButton, isNotNull,
      reason: '應找到按鈕: ${labels.join(' / ')}');
  await tester.ensureVisible(actionButton!);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(actionButton, warnIfMissed: false);
}

Future<void> _stopServiceIfRunning(WidgetTester tester) async {
  final stopFinder = _findFirstVisibleText(_stopLabels);
  if (stopFinder.evaluate().isEmpty) return;

  await tester.tap(stopFinder);
  await _waitForAnyText(tester, _startLabels,
      timeout: const Duration(seconds: 20));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterForegroundTaskPlatform originalPlatform;

  setUpAll(() {
    originalPlatform = FlutterForegroundTaskPlatform.instance;
    FlutterForegroundTaskPlatform.instance =
        _PermissionGrantedForegroundTaskPlatform();
  });

  tearDownAll(() {
    FlutterForegroundTaskPlatform.instance = originalPlatform;
  });

  setUp(() {
    FlutterForegroundTaskPlatform.instance =
        _PermissionGrantedForegroundTaskPlatform();
  });

  group('Bilirec App 整合測試（模擬器可視化）', () {
    testWidgets('1. 首頁標題與初始狀態正確顯示', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(_findFirstVisibleText(_titleLabels), findsOneWidget);
      expect(_findFirstVisibleText(_startLabels), findsOneWidget);
      expect(_findFirstVisibleText(_settingsLabels), findsOneWidget);

      // 行為按鈕只會在服務運行中顯示。
      for (final label in _checkConnectionLabels) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('2. 可開啟設定抽屜並顯示最新設定項目', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(_findFirstVisibleText(_settingsLabels));
      await tester.pumpAndSettle();

      expect(find.text('設定錄製輸出路徑'), findsOneWidget);
      expect(find.text('儲存路徑'), findsOneWidget);
      expect(find.text('變更路徑'), findsOneWidget);
      expect(find.text('通知模式設定'), findsOneWidget);
      expect(find.text('本地通知模式'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('3. 啟動服務後顯示動作區並可檢查連線', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(_findFirstVisibleText(_startLabels));
      await tester.pump(const Duration(milliseconds: 500));

      final canContinue =
          find.text('目前只支援 Android').evaluate().isNotEmpty == false;
      if (!canContinue) return;

      await _waitForAnyText(
        tester,
        [..._startingStatusLabels, ..._runningStatusLabels],
        timeout: const Duration(seconds: 25),
      );
      await _waitForAnyText(tester, _runningStatusLabels,
          timeout: const Duration(seconds: 35));

      expect(_findFirstVisibleText(_openFrontendLabels), findsOneWidget);
      expect(_findFirstVisibleText(_checkConnectionLabels), findsOneWidget);

      await _tapActionButton(tester, _checkConnectionLabels);

      var snackbarShown = false;
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          snackbarShown = true;
          break;
        }
      }

      expect(snackbarShown, isTrue, reason: '應顯示後端連線檢測結果 Snackbar');

      await _stopServiceIfRunning(tester);
    });

    testWidgets('4. 電池無限制 dialog 在模擬器上出現（Android 環境）', (tester) async {
      FlutterForegroundTaskPlatform.instance =
          _BatteryDialogForegroundTaskPlatform();
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance =
            _PermissionGrantedForegroundTaskPlatform();
      });

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('需要關閉省電限制'), findsOneWidget);
      expect(find.text('前往設定'), findsOneWidget);
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

      expect(_findFirstVisibleText(_titleLabels), findsOneWidget);
      expect(_findFirstVisibleText(_startLabels), findsOneWidget);

      await tester.tap(_findFirstVisibleText(_startLabels));
      await tester.pump(const Duration(milliseconds: 500));
      await _waitForAnyText(tester, _runningStatusLabels,
          timeout: const Duration(seconds: 35));

      await _tapActionButton(tester, _checkConnectionLabels);
      var snackbarShown = false;
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          snackbarShown = true;
          break;
        }
      }
      expect(snackbarShown, isTrue, reason: '全流程中應顯示連線檢測結果 Snackbar');

      await _tapPrimaryButton(tester, _openFrontendLabels);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(fakeUrlLauncher.didLaunch, isTrue,
          reason: '全流程中應觸發啟動前端跳轉');

      await _stopServiceIfRunning(tester);
    });
  });
}

