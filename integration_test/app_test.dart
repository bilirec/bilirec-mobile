import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_method_channel.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:bilirec/main.dart' as app;

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

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(minutes: 1),
  Duration step = const Duration(seconds: 1),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < maxTicks; i++) {
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }

  expect(find.text(text), findsOneWidget,
      reason: '在 ${timeout.inSeconds} 秒內應看到「$text」');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterForegroundTaskPlatform originalPlatform;

  setUpAll(() {
    originalPlatform = FlutterForegroundTaskPlatform.instance;
    FlutterForegroundTaskPlatform.instance =
        _BatteryBypassForegroundTaskPlatform();
  });

  tearDownAll(() {
    FlutterForegroundTaskPlatform.instance = originalPlatform;
  });

  setUp(() {
    FlutterForegroundTaskPlatform.instance =
        _BatteryBypassForegroundTaskPlatform();
  });

  group('Bilirec App 整合測試（模擬器可視化）', () {
    testWidgets('1. 首頁標題與初始狀態正確顯示', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 頂部 AppBar 標題
      expect(find.text('Bilirec 後台服務控制中心'), findsOneWidget);

      // 啟動按鈕文字（服務未運行時顯示「啟動」）
      expect(find.text('啟動'), findsOneWidget);

      // 底部檢測按鈕
      expect(find.text('檢測後端連線'), findsOneWidget);

      // 路徑設置卡片
      expect(find.text('設置錄製輸出路徑'), findsOneWidget);
    });

    testWidgets('2. 點擊啟動按鈕後顯示狀態變化', (tester) async {
      FlutterForegroundTaskPlatform.instance =
          _PermissionGrantedForegroundTaskPlatform();
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance =
            _BatteryBypassForegroundTaskPlatform();
      });

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 點擊啟動按鈕
      await tester.tap(find.text('啟動'));
      await tester.pump(const Duration(milliseconds: 500));

      // 按鈕應顯示啟動中... 或顯示限制訊息（非 Android 環境）
      final isStarting = find.text('正在啟動服務...').evaluate().isNotEmpty ||
          find.text('啟動中...').evaluate().isNotEmpty;
      final isForegroundStarted =
          find.text('前景服務已啟動，等待核心回報...').evaluate().isNotEmpty;
      final isRestricted =
          find.text('目前僅支援 Android 前景服務').evaluate().isNotEmpty;

      expect(isStarting || isForegroundStarted || isRestricted, isTrue,
          reason: '點擊後應顯示啟動中、前景服務已啟動，或平台限制訊息');

      await _waitForText(tester, 'Bilirec 後端運行中');

      if (find.text('停止').evaluate().isNotEmpty) {
        await tester.tap(find.text('停止'));
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets('3. 點擊「檢測後端連線」顯示 Snackbar 回應', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('檢測後端連線'));

      var snackbarShown = false;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          snackbarShown = true;
          break;
        }
      }

      expect(snackbarShown, isTrue, reason: '應顯示後端連線檢測結果 Snackbar');
    });

    testWidgets('4. 路徑設定卡片及瀏覽按鈕存在', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('設置錄製輸出路徑'), findsOneWidget);
      expect(find.text('瀏覽並設置輸出路徑'), findsOneWidget);
    });

    testWidgets('5. 電池無限制 dialog 在模擬器上出現（Android 環境）', (tester) async {
      FlutterForegroundTaskPlatform.instance =
          _BatteryDialogForegroundTaskPlatform();
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance =
            _BatteryBypassForegroundTaskPlatform();
      });

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('需要電池無限制'), findsOneWidget);
      expect(find.text('前往設定'), findsOneWidget);
      // 不真的送出，避免跳出測試 App
    });

    testWidgets('6. 全流程：開啟→啟動成功→測連線→啟動前端', (tester) async {
      FlutterForegroundTaskPlatform.instance =
          _PermissionGrantedForegroundTaskPlatform();
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance =
            _BatteryBypassForegroundTaskPlatform();
      });

      final originalUrlLauncher = UrlLauncherPlatform.instance;
      final fakeUrlLauncher = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakeUrlLauncher;
      addTearDown(() {
        UrlLauncherPlatform.instance = originalUrlLauncher;
      });

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Bilirec 後台服務控制中心'), findsOneWidget);
      expect(find.text('啟動'), findsOneWidget);

      await tester.tap(find.text('啟動'));
      await tester.pump(const Duration(milliseconds: 500));
      await _waitForText(tester, 'Bilirec 後端運行中');

      await tester.tap(find.text('檢測後端連線'));
      var snackbarShown = false;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          snackbarShown = true;
          break;
        }
      }
      expect(snackbarShown, isTrue, reason: '全流程中應顯示連線檢測結果 Snackbar');

      await tester.tap(find.text('啟動前端'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(fakeUrlLauncher.didLaunch, isTrue,
          reason: '全流程中應觸發啟動前端跳轉');

      if (find.text('停止').evaluate().isNotEmpty) {
        await tester.tap(find.text('停止'));
        await tester.pump(const Duration(milliseconds: 500));
      }
    });
  });
}

