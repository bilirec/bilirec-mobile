import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'test_support/in_memory_shared_preferences_async_platform.dart';
import 'test_support/l10n_test_helper.dart';

const String _unreachableCustomGitHubApiBase = 'http://127.0.0.1:1/';
const Duration _githubApiCustomDebounce = Duration(milliseconds: 600);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final fakeAsyncPrefs = InMemorySharedPreferencesAsyncPlatform();
  final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;

  final _githubApiProxyTitle = labelForKeyAndCode(
    'githubApiProxyTitle',
    AppLocaleConfig.traditionalCode,
  );
  final _githubApiProxyCustomLabel = labelForKeyAndCode(
    'githubApiProxyCustomLabel',
    AppLocaleConfig.traditionalCode,
  );
  final _githubApiProxyOptionCustom = labelForKeyAndCode(
    'githubApiProxyOptionCustom',
    AppLocaleConfig.traditionalCode,
  );
  final _githubApiProxyCustomUnreachable = labelForKeyAndCode(
    'githubApiProxyCustomUnreachable',
    AppLocaleConfig.traditionalCode,
  );

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
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return 'C:/mock/support';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  Future<void> pumpSettingsSheet(WidgetTester tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.traditionalLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SettingsDrawerSheet(
            scrollController: scrollController,
            controlsEnabled: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder _githubProxyCustomField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == _githubApiProxyCustomLabel,
    );
  }

  Future<bool> _waitForFinder(WidgetTester tester, Finder finder) async {
    const step = Duration(milliseconds: 100);
    const maxWait = Duration(seconds: 15);
    final maxTicks = maxWait.inMilliseconds ~/ step.inMilliseconds;
    for (var i = 0; i < maxTicks; i++) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  testWidgets('自訂 GitHub 反代輸入 debounce 後驗證失敗顯示欄位錯誤', (tester) async {
    await pumpSettingsSheet(tester);

    await tester.scrollUntilVisible(
      find.text(_githubApiProxyTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_githubApiProxyOptionCustom).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      _githubProxyCustomField(),
      _unreachableCustomGitHubApiBase,
    );
    await tester.pump(_githubApiCustomDebounce);

    expect(
      await _waitForFinder(
        tester,
        find.text(_githubApiProxyCustomUnreachable),
      ),
      isTrue,
    );
  });
}
