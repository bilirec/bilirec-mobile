import 'package:flutter/services.dart';
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

    expect(find.text('Bilirec 後臺服務控制中心'), findsOneWidget);
    expect(find.text('Bilirec 後端未運行'), findsOneWidget);
    expect(find.text('啟動'), findsOneWidget);
    expect(find.text('檢測後端連線'), findsOneWidget);
  });

  testWidgets('初次載入會自動帶入並顯示預設 base path', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    expect(find.text('目前路徑: C:/mock/support'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('base_path'), 'C:/mock/support');
  });

  testWidgets('在非 Android 環境點擊啟動會顯示限制訊息', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('啟動'));
    await tester.pump();

    expect(find.text('目前僅支援 Android 前景服務'), findsOneWidget);
  });
}
