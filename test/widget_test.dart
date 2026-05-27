import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/main.dart';
import 'package:bilirec/shared/preferences.dart';
import 'test_support/in_memory_shared_preferences_async_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const foregroundChannel = MethodChannel('flutter_foreground_task/methods');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  final fakeAsyncPrefs = InMemorySharedPreferencesAsyncPlatform();
  final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance = fakeAsyncPrefs;
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeAsyncPrefs.reset();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundChannel, (call) async {
      if (call.method == 'isRunningService') {
        return false;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return 'C:/mock/support';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('載入後顯示主控制頁與未運行狀態', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    expect(find.text('Bilirec 服務控制中心'), findsOneWidget);
    expect(find.text('Bilirec 系統服務未啟動'), findsOneWidget);
    expect(find.text('啟動'), findsOneWidget);
  });

  testWidgets('初次載入會顯示設定按鈕與抽屜內容', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    expect(find.text('打開服務啓動設定'), findsOneWidget);

    await tester.tap(find.text('打開服務啓動設定'));
    await tester.pumpAndSettle();

    expect(find.text('儲存路徑'), findsOneWidget);
    expect(find.text('目前尚未設定輸出路徑（使用預設）'), findsOneWidget);
    expect(find.text('變更路徑'), findsOneWidget);
    expect(find.text('通知模式設定'), findsOneWidget);
    expect(find.text('本地通知模式'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(
      find.text(
        '如在中國大陸網絡環境下無法接收開播/錄製通知推送，可嘗試啟用此模式。',
      ),
      findsOneWidget,
    );
    expect(find.text('將於啟動服務後生效'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('output_dir'), isNull);
  });

  testWidgets('服務啟動後設定按鈕會被禁用', (tester) async {
    SharedPreferences.setMockInitialValues({
      'com.pravera.flutter_foreground_task.prefs.$coreRunningKey': true,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundChannel, (call) async {
      switch (call.method) {
        case 'isRunningService':
          return true;
        default:
          return null;
      }
    });

    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    final settingsCard = tester.widget<SettingsCard>(
      find.byType(SettingsCard),
    );
    expect(settingsCard.enabled, isFalse);
  });

  testWidgets('在非 Android 環境點擊啟動會顯示限制訊息', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('啟動'));
    await tester.pump();

    expect(find.text('目前只支援 Android'), findsOneWidget);
  });

  testWidgets('語言切換會即時同步所有文案', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('繁'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<String>).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Bilirec 服务控制中心'), findsOneWidget);
    expect(find.text('Bilirec 系统服务未启动'), findsOneWidget);

    await tester.tap(find.text('简'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<String>).at(0));
    await tester.pumpAndSettle();

    expect(find.text('Bilirec 服務控制中心'), findsOneWidget);
    expect(find.text('Bilirec 系統服務未啟動'), findsOneWidget);
  });
}
