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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final fakeAsyncPrefs = InMemorySharedPreferencesAsyncPlatform();
  final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;

  final _githubApiProxyTitle = labelForKeyAndCode(
    'githubApiProxyTitle',
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
  final _githubApiProxyCustomEdit = labelForKeyAndCode(
    'githubApiProxyCustomEdit',
    AppLocaleConfig.traditionalCode,
  );
  final _githubApiProxyCustomSave = labelForKeyAndCode(
    'githubApiProxyCustomSave',
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

  testWidgets('選自訂不彈窗；編輯後提交 API 驗證失敗顯示錯誤', (tester) async {
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

    expect(find.byKey(const Key('github_proxy_custom_api_field')), findsNothing);

    await tester.tap(find.text(_githubApiProxyCustomEdit));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('github_proxy_custom_api_field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('github_proxy_custom_api_field')),
      _unreachableCustomGitHubApiBase,
    );
    await tester.pump();

    await tester.ensureVisible(find.text(_githubApiProxyCustomSave));
    await tester.tap(find.text(_githubApiProxyCustomSave));
    await tester.pump();

    expect(
      await _waitForFinder(
        tester,
        find.text(_githubApiProxyCustomUnreachable),
      ),
      isTrue,
    );
  });
}
