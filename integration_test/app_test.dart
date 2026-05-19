import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bilirec/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bilirec App 整合測試（模擬器可視化）', () {
    testWidgets('1. 首頁標題與初始狀態正確顯示', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 頂部 AppBar 標題
      expect(find.text('Bilirec 後臺服務控制中心'), findsOneWidget);

      // 啟動按鈕文字（服務未運行時顯示「啟動」）
      expect(find.text('啟動'), findsOneWidget);

      // 底部檢測按鈕
      expect(find.text('檢測後端連線'), findsOneWidget);

      // 路徑設置卡片
      expect(find.text('設置檔案輸出路徑'), findsOneWidget);
    });

    testWidgets('2. 點擊啟動按鈕後顯示狀態變化', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 點擊啟動按鈕
      await tester.tap(find.text('啟動'));
      await tester.pump(const Duration(milliseconds: 500));

      // 按鈕應顯示啟動中... 或顯示限制訊息（非 Android 環境）
      final isStarting = find.text('啟動中...').evaluate().isNotEmpty;
      final isRestricted =
          find.text('目前僅支援 Android 前景服務').evaluate().isNotEmpty;

      expect(isStarting || isRestricted, isTrue,
          reason: '點擊後應顯示啟動中或平台限制訊息');

      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('3. 點擊「檢測後端連線」顯示 Snackbar 回應', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('檢測後端連線'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // 其中一個 snackbar 應出現
      final snackMessages = [
        '後端服務正常，可以連線',
        '後端服務回應異常，請稍後再試',
        '後端服務無回應，請確認服務是否已啟動',
        '無法連線至後端服務，請確認服務是否已啟動',
      ];
      final found = snackMessages.any(
        (msg) => find.text(msg).evaluate().isNotEmpty,
      );
      expect(found, isTrue, reason: '應顯示後端連線檢測結果 Snackbar');
    });

    testWidgets('4. 路徑設定卡片及瀏覽按鈕存在', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('設置檔案輸出路徑'), findsOneWidget);
      expect(find.text('瀏覽並設置路徑'), findsOneWidget);
    });

    testWidgets('5. 電池無限制 dialog 在模擬器上出現（Android 環境）', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 若是 Android 且未設定無限制，dialog 應出現
      final batteryDialog = find.text('需要電池無限制');
      if (batteryDialog.evaluate().isNotEmpty) {
        expect(batteryDialog, findsOneWidget);
        expect(find.text('前往設定'), findsOneWidget);
        // 不真的送出，避免跳出測試 App
      }
      // 若未出現（已設定好），也算通過
    });
  });
}

