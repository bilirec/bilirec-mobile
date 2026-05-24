import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilirec/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const foregroundChannel = MethodChannel('flutter_foreground_task/methods');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({});

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

  testWidgets('初次載入會顯示預設輸出路徑提示', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    expect(find.text('目前尚未設定輸出路徑（使用預設）'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('output_dir'), isNull);
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
