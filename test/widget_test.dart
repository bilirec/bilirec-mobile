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

Finder _findFirstVisibleContainingText(Iterable<String> labels) {
  for (final label in labels) {
    final finder = find.textContaining(label);
    if (finder.evaluate().isNotEmpty) {
      return finder;
    }
  }
  return find.textContaining(labels.first);
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

Finder _findSwitchInTileByLabels(Iterable<String> labels) {
  final labelFinder = _findFirstVisibleText(labels).first;
  final tileFinder = find.ancestor(
    of: labelFinder,
    matching: find.byType(SwitchListTile),
  );
  expect(tileFinder, findsWidgets, reason: '找不到開關列: ${labels.join(' / ')}');

  final switchFinder = find.descendant(
    of: tileFinder.first,
    matching: find.byType(Switch),
  );
  expect(switchFinder, findsWidgets, reason: '找不到開關: ${labels.join(' / ')}');
  return switchFinder.first;
}

Future<void> _setSwitchByLabels(
  WidgetTester tester, {
  required Iterable<String> labels,
  required bool enabled,
}) async {
  final switchFinder = _findSwitchInTileByLabels(labels);
  final switchWidget = tester.widget<Switch>(switchFinder);
  final current = switchWidget.value;
  if (current != enabled) {
    expect(switchWidget.onChanged, isNotNull,
        reason: '開關目前不可操作: ${labels.join(' / ')}');
    switchWidget.onChanged!(enabled);
    await tester.pumpAndSettle();
  }
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
final _antiSleepDisabledHintLabels = labelsForKey('antiSleepDisabledHint');
final _recordingPolicyTitleLabels = labelsForKey('recordingPolicyTitle');
final _recordingPolicyDescriptionLabels =
    labelsForKey('recordingPolicyDescription');
final _maxRecordingHoursTitleLabels = labelsForKey('maxRecordingHoursTitle');
final _minDiskSpaceTitleLabels = labelsForKey('minDiskSpaceTitle');
final _maxRetryMinutesTitleLabels = labelsForKey('maxRetryMinutesTitle');
final _maxConcurrentRecordingsTitleLabels =
    labelsForKey('maxConcurrentRecordingsTitle');
final _maxConcurrentRecordingsWarningLabels =
    labelsForKey('maxConcurrentRecordingsWarning');
final _fileConversionTitleLabels = labelsForKey('fileConversionTitle');
final _convertToMp4TitleLabels = labelsForKey('convertToMp4Title');
final _convertToMp4DescriptionLabels = labelsForKey('convertToMp4Description');
final _deleteSourceAfterConvertTitleLabels =
    labelsForKey('deleteSourceAfterConvertTitle');
final _developerSettingsTitleLabels = labelsForKey('developerSettingsTitle');
final _developerSectionDescriptionLabels =
    labelsForKey('developerSectionDescription');
final _environmentSettingsTitleLabels = labelsForKey('environmentSettingsTitle');
final _environmentSettingsWarningLabels = labelsForKey('environmentSettingsWarning');
final _addEnvironmentSettingLabels = labelsForKey('addEnvironmentSetting');
final _saveEnvironmentSettingLabels = labelsForKey('saveEnvironmentSetting');
final _bootstrapLogTitleLabels = labelsForKey('bootstrapLogTitle');
final _bootstrapLogDescriptionLabels = labelsForKey('bootstrapLogDescription');
final _downloadBootstrapLogLabels = labelsForKey('downloadBootstrapLog');
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
    expect(find.byType(Switch), findsWidgets);
    expect(_findFirstVisibleText(_ssePushDescriptionLabels), findsOneWidget);
    expect(_findFirstVisibleText(_ssePushHintLabels), findsOneWidget);
    expect(_findFirstVisibleText(_antiSleepDisabledHintLabels), findsOneWidget);
    expect(_findFirstVisibleText(_recordingPolicyTitleLabels), findsOneWidget);
    expect(
      _findFirstVisibleText(_recordingPolicyDescriptionLabels),
      findsOneWidget,
    );
    expect(_findFirstVisibleText(_maxRecordingHoursTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_minDiskSpaceTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_maxRetryMinutesTitleLabels), findsOneWidget);
    expect(
      _findFirstVisibleText(_maxConcurrentRecordingsTitleLabels),
      findsOneWidget,
    );
    expect(
      _findFirstVisibleText(_maxConcurrentRecordingsWarningLabels),
      findsOneWidget,
    );
    expect(_findFirstVisibleText(_fileConversionTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_convertToMp4TitleLabels), findsOneWidget);
    expect(
      _findFirstVisibleText(_convertToMp4DescriptionLabels),
      findsOneWidget,
    );
    expect(
      _findFirstVisibleText(_deleteSourceAfterConvertTitleLabels),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsWidgets);
    expect(_findFirstVisibleText(_developerSettingsTitleLabels), findsOneWidget);
    expect(
      _findFirstVisibleText(_developerSectionDescriptionLabels),
      findsOneWidget,
    );
    expect(_findFirstVisibleText(_environmentSettingsTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_environmentSettingsWarningLabels), findsOneWidget);
    expect(_findFirstVisibleText(_bootstrapLogTitleLabels), findsOneWidget);
    expect(_findFirstVisibleText(_bootstrapLogDescriptionLabels), findsOneWidget);
    expect(
      _findFirstWidgetWithText(FilledButton, _downloadBootstrapLogLabels),
      findsOneWidget,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('output_dir'), isNull);
  });

  testWidgets('bootstrap log 下載按鈕可點擊', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    await tester.tap(_findFirstVisibleText(_settingsLabels));
    await tester.pumpAndSettle();

    final downloadButton =
        _findFirstWidgetWithText(FilledButton, _downloadBootstrapLogLabels);
    await tester.scrollUntilVisible(
      downloadButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(downloadButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
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

    final envSettings = await Preferences.getDevelopEnvironmentSettings();
    expect(envSettings['BILIREC_ENV'], 'staging');
  });

  testWidgets('錄製策略設定變更會更新環境參數', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();

    await tester.tap(_findFirstVisibleText(_settingsLabels));
    await tester.pumpAndSettle();

    final sliders = tester.widgetList<Slider>(find.byType(Slider));

    // 設定順序：時長上限、啟動前可用空間、斷線等待、同時錄製上限。
    sliders.elementAt(0).onChanged?.call(12);
    sliders.elementAt(0).onChangeEnd?.call(12);
    await tester.pumpAndSettle();
    sliders.elementAt(1).onChanged?.call(2); // 2GB,5GB,10GB -> index 2
    sliders.elementAt(1).onChangeEnd?.call(2);
    await tester.pumpAndSettle();
    sliders.elementAt(2).onChanged?.call(5); // 5,10,15,20,25,30 -> index 5
    sliders.elementAt(2).onChangeEnd?.call(5);
    await tester.pumpAndSettle();
    sliders.elementAt(3).onChanged?.call(3); // 3,4,5,6 -> index 3
    sliders.elementAt(3).onChangeEnd?.call(3);
    await tester.pumpAndSettle();

    await _setSwitchByLabels(
      tester,
      labels: _convertToMp4TitleLabels,
      enabled: true,
    );
    await _setSwitchByLabels(
      tester,
      labels: _deleteSourceAfterConvertTitleLabels,
      enabled: true,
    );

    final envSettings = await Preferences.getManagedEnvironmentSettings();
    expect(envSettings['MAX_RECORDING_HOURS'], '12');
    expect(
      envSettings['MIN_DISK_SPACE_BYTES'],
      '${10 * 1024 * 1024 * 1024}',
    );
    expect(envSettings['MAX_RETRY_MINUTES'], '30');
    expect(envSettings['MAX_CONCURRENT_RECORDINGS'], '6');
    expect(envSettings['CONVERT_TO_MP4'], 'true');
    expect(envSettings['DELETE_SOURCE_AFTER_CONVERT'], 'true');
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
