import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/main.dart';
import 'package:bilirec/shared/preferences.dart';
import 'test_support/l10n_test_helper.dart';
import 'test_support/in_memory_shared_preferences_async_platform.dart';

Finder _findFirstVisibleText(Iterable<String> labels) {
  for (final label in labels) {
    final finder = find.text(label);
    if (finder.evaluate().isNotEmpty) {
      return finder;
    }
  }
  return find.text(labels.first);
}

Finder _findFirstWidgetWithText(Type widgetType, Iterable<String> labels) {
  for (final label in labels) {
    final finder = find.widgetWithText(widgetType, label);
    if (finder.evaluate().isNotEmpty) {
      return finder;
    }
  }
  return find.widgetWithText(widgetType, labels.first);
}

final _controlCenterTitleLabels = labelsForKey('controlCenterTitle');
final _backendNotRunningLabels = labelsForKey('backendNotRunning');
final _startLabels = labelsForKey('start');
final _settingsLabels = labelsForKey('settings');
final _generalSettingsTitleLabels = labelsForKey('generalSettingsTitle');
final _storagePathTitleLabels = labelsForKey('storagePathTitle');
final _outputPathUnsetLabels = labelsForKey('outputPathUnset');
final _changePathLabels = labelsForKey('changePath');
final _ssePushSwitchTitleLabels = labelsForKey('ssePushSwitchTitle');
final _ssePushDescriptionLabels = labelsForKey('ssePushDescription');
final _ssePushHintLabels = labelsForKey('ssePushHint');
final _developerSettingsTitleLabels = labelsForKey('developerSettingsTitle');
final _environmentSettingsTitleLabels = labelsForKey('environmentSettingsTitle');
final _addEnvironmentSettingLabels = labelsForKey('addEnvironmentSetting');
final _saveEnvironmentSettingLabels = labelsForKey('saveEnvironmentSetting');
final _androidOnlyLabels = labelsForKey('androidOnly');
final _languageTraditionalLabels = labelsForKey('languageTraditional');
final _languageSimplifiedLabels = labelsForKey('languageSimplified');
final _traditionalControlCenterTitle =
    labelForKeyAndCode('controlCenterTitle', AppLocaleConfig.traditionalCode);
final _simplifiedControlCenterTitle =
    labelForKeyAndCode('controlCenterTitle', AppLocaleConfig.simplifiedCode);
final _traditionalBackendNotRunning =
    labelForKeyAndCode('backendNotRunning', AppLocaleConfig.traditionalCode);
final _simplifiedBackendNotRunning =
    labelForKeyAndCode('backendNotRunning', AppLocaleConfig.simplifiedCode);

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

    expect(_findFirstVisibleText(_controlCenterTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_backendNotRunningLabels), findsOneWidget);
    expect(_findFirstVisibleText(_startLabels), findsOneWidget);
  });

  testWidgets('初次載入會顯示設定按鈕與抽屜內容', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    expect(_findFirstVisibleText(_settingsLabels), findsOneWidget);

    await tester.tap(_findFirstVisibleText(_settingsLabels));
    await tester.pumpAndSettle();

    expect(_findFirstVisibleText(_generalSettingsTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_storagePathTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_outputPathUnsetLabels), findsOneWidget);
    expect(_findFirstVisibleText(_changePathLabels), findsOneWidget);
    expect(_findFirstVisibleText(_ssePushSwitchTitleLabels), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(_findFirstVisibleText(_ssePushDescriptionLabels), findsOneWidget);
    expect(_findFirstVisibleText(_ssePushHintLabels), findsOneWidget);
    expect(_findFirstVisibleText(_developerSettingsTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_environmentSettingsTitleLabels), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('output_dir'), isNull);
  });

  testWidgets('可透過 dialog 新增環境參數並持久化', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    await tester.tap(_findFirstVisibleText(_settingsLabels));
    await tester.pumpAndSettle();

    final addEnvironmentButton = find.widgetWithIcon(OutlinedButton, Icons.add);
    await tester.ensureVisible(addEnvironmentButton);
    await tester.tap(addEnvironmentButton);
    await tester.pumpAndSettle();

    expect(_findFirstVisibleText(_addEnvironmentSettingLabels), findsNWidgets(2));
    expect(_findFirstVisibleText(_saveEnvironmentSettingLabels), findsOneWidget);
    expect(find.byKey(const Key('env_key_input')), findsOneWidget);
    expect(find.byKey(const Key('env_value_input')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('env_key_input')), 'BILIREC_ENV');
    await tester.enterText(find.byKey(const Key('env_value_input')), 'staging');

    await tester.tap(
      _findFirstWidgetWithText(FilledButton, _saveEnvironmentSettingLabels),
    );
    await tester.pumpAndSettle();

    expect(find.text('BILIREC_ENV'), findsOneWidget);
    expect(find.text('staging'), findsOneWidget);

    final envSettings = await Preferences.getEnvironmentSettings();
    expect(envSettings['BILIREC_ENV'], 'staging');
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

    await tester.tap(_findFirstVisibleText(_startLabels));
    await tester.pump();

    expect(_findFirstVisibleText(_androidOnlyLabels), findsOneWidget);
  });

  testWidgets('語言切換會即時同步所有文案', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    await tester.tap(_findFirstVisibleText(_languageTraditionalLabels));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<String>).at(1));
    await tester.pumpAndSettle();

    expect(find.text(_simplifiedControlCenterTitle), findsOneWidget);
    expect(find.text(_simplifiedBackendNotRunning), findsOneWidget);

    await tester.tap(_findFirstVisibleText(_languageSimplifiedLabels));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<String>).at(0));
    await tester.pumpAndSettle();

    expect(find.text(_traditionalControlCenterTitle), findsOneWidget);
    expect(find.text(_traditionalBackendNotRunning), findsOneWidget);
  });
}
