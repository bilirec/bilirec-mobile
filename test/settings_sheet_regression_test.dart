import 'package:bilirec/app/widgets/settings/settings_option_slider.dart';
import 'package:bilirec/app/widgets/settings/settings_range_slider.dart';
import 'package:bilirec/main.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/storage_protection_env.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'test_support/in_memory_shared_preferences_async_platform.dart';
import 'test_support/l10n_test_helper.dart';

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

Finder _findRowSwitchByLabels(Iterable<String> labels) {
  final labelFinder = _findFirstVisibleText(labels).first;
  final switchFinder = find.descendant(
    of: find.ancestor(of: labelFinder, matching: find.byType(Row)).first,
    matching: find.byType(Switch),
  );
  expect(switchFinder, findsOneWidget, reason: '找不到開關: ${labels.join(' / ')}');
  return switchFinder;
}

Finder _findTileSwitchByLabels(Iterable<String> labels) {
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

SettingsRangeSlider _rangeSliderByTitle(
  WidgetTester tester,
  Iterable<String> titles,
) {
  for (final title in titles) {
    final finder = find.byWidgetPredicate(
      (widget) => widget is SettingsRangeSlider && widget.title == title,
    );
    if (finder.evaluate().isNotEmpty) {
      return tester.widget<SettingsRangeSlider>(finder);
    }
  }
  fail('找不到 SettingsRangeSlider: ${titles.join(' / ')}');
}

SettingsOptionSlider _optionSliderByTitle(
  WidgetTester tester,
  Iterable<String> titles,
) {
  for (final title in titles) {
    final finder = find.byWidgetPredicate(
      (widget) => widget is SettingsOptionSlider && widget.title == title,
    );
    if (finder.evaluate().isNotEmpty) {
      return tester.widget<SettingsOptionSlider>(finder);
    }
  }
  fail('找不到 SettingsOptionSlider: ${titles.join(' / ')}');
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(_findFirstVisibleText(_settingsLabels));
  await tester.pumpAndSettle();
}

Future<void> _closeSettings(WidgetTester tester) async {
  final sheetFinder = find.byType(BottomSheet);
  if (sheetFinder.evaluate().isNotEmpty) {
    Navigator.of(tester.element(sheetFinder.first)).pop();
    await tester.pumpAndSettle();
  }
}

final _settingsLabels = labelsForKey('settings');
final _ssePushSwitchTitleLabels = labelsForKey('ssePushSwitchTitle');
final _antiSleepTitleLabels = labelsForKey('antiSleepTitle');
final _autoRunOnBootTitleLabels = labelsForKey('autoRunOnBootTitle');
final _outputPathUnsetLabels = labelsForKey('outputPathUnset');
final _restoreDefaultPathLabels = labelsForKey('restoreDefaultPath');
final _microSdWearProtectionTitleLabels =
    labelsForKey('microSdWearProtectionTitle');
final _maxRecordingHoursTitleLabels = labelsForKey('maxRecordingHoursTitle');
final _maxConcurrentRecordingsTitleLabels =
    labelsForKey('maxConcurrentRecordingsTitle');
final _hoursUnlimitedLabels = labelsForKey('hoursUnlimitedOption');
final _diskSpaceNoMinimumLabels = labelsForKey('diskSpaceNoMinimumOption');
final _danmakuOverflowPolicyBlockHintLabels =
    labelsForKey('danmakuOverflowPolicyBlockHint');
final _convertToMp4TitleLabels = labelsForKey('convertToMp4Title');
final _deleteSourceAfterConvertTitleLabels =
    labelsForKey('deleteSourceAfterConvertTitle');
final _ffmpegAllowDuringRecordingTitleLabels =
    labelsForKey('ffmpegAllowDuringRecordingTitle');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const foregroundChannel = MethodChannel('flutter_foreground_task/methods');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const browserPackagesChannel =
      MethodChannel('org.bilirec.bilirec/browser_packages');

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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(browserPackagesChannel, (call) async {
      if (call.method == 'listHttpsBrowsers') {
        return <dynamic>[];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(browserPackagesChannel, null);
  });

  testWidgets('兩筆 managed 寫入重疊時兩組鍵都留下', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    final hoursSlider = _rangeSliderByTitle(
      tester,
      _maxRecordingHoursTitleLabels,
    );
    final microSdSwitch = tester.widget<Switch>(
      _findRowSwitchByLabels(_microSdWearProtectionTitleLabels),
    );

    hoursSlider.onChangeEnd?.call(12);
    microSdSwitch.onChanged?.call(true);
    await tester.pumpAndSettle();

    final env = await Preferences.getManagedEnvironmentSettings();
    expect(env['MAX_RECORDING_HOURS'], '12');
    expect(env['SEQUENTIAL_WRITE'], 'true');
    expect(env['LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS'], isNotNull);
    expect(env['DANMAKU_WRITER_FLUSH_PERIOD_SECS'], isNotNull);
  });

  testWidgets('已存值在打開抽屜時回填', (tester) async {
    const outputPath = 'C:/recordings/custom';
    await Preferences.setEnableSsePush(true);
    await Preferences.setEnableAntiSleep(true);
    await Preferences.setEnableAutoRunOnBoot(true);
    await Preferences.setOutputDir(outputPath);
    await Preferences.setManagedEnvironmentSettings(
      applyStorageProtectionEnv(
        env: <String, String>{
          'MAX_RECORDING_HOURS': '0',
          'MIN_DISK_SPACE_BYTES': '0',
          'SUBCHECK_MIN_INTERVAL_SECS': '120',
          'DANMAKU_OUTPUT_FORMAT': 'xml',
          'DANMAKU_OVERFLOW_POLICY': 'block',
          'CONVERT_TO_MP4': 'true',
          'DELETE_SOURCE_AFTER_CONVERT': 'true',
        },
        protectionEnabled: true,
        maxConcurrent: 3,
      ),
    );

    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(
      tester
          .widget<Switch>(_findRowSwitchByLabels(_ssePushSwitchTitleLabels))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(_findRowSwitchByLabels(_antiSleepTitleLabels))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(_findRowSwitchByLabels(_autoRunOnBootTitleLabels))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(
            _findRowSwitchByLabels(_microSdWearProtectionTitleLabels),
          )
          .value,
      isTrue,
    );
    expect(find.text(outputPath), findsOneWidget);
    expect(_findFirstVisibleText(_hoursUnlimitedLabels), findsOneWidget);
    expect(_findFirstVisibleText(_diskSpaceNoMinimumLabels), findsOneWidget);
    expect(
      tester
          .widget<SettingsOptionSlider>(
            find.byKey(const Key('subcheck_min_interval_slider')),
          )
          .value,
      120,
    );
    expect(_findFirstVisibleText(_danmakuOverflowPolicyBlockHintLabels),
        findsOneWidget);
    expect(
      tester
          .widget<Switch>(_findTileSwitchByLabels(_convertToMp4TitleLabels))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(
            _findTileSwitchByLabels(_deleteSourceAfterConvertTitleLabels),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('三個一般開關寫入後重開仍在', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    tester
        .widget<Switch>(_findRowSwitchByLabels(_ssePushSwitchTitleLabels))
        .onChanged!(true);
    await tester.pumpAndSettle();
    tester
        .widget<Switch>(_findRowSwitchByLabels(_antiSleepTitleLabels))
        .onChanged!(true);
    await tester.pumpAndSettle();
    tester
        .widget<Switch>(_findRowSwitchByLabels(_autoRunOnBootTitleLabels))
        .onChanged!(true);
    await tester.pumpAndSettle();

    expect(await Preferences.getEnableSsePush(), isTrue);
    expect(await Preferences.getEnableAntiSleep(), isTrue);
    expect(await Preferences.getEnableAutoRunOnBoot(), isTrue);

    await _closeSettings(tester);
    await _openSettings(tester);

    expect(
      tester
          .widget<Switch>(_findRowSwitchByLabels(_ssePushSwitchTitleLabels))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(_findRowSwitchByLabels(_antiSleepTitleLabels))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(_findRowSwitchByLabels(_autoRunOnBootTitleLabels))
          .value,
      isTrue,
    );
  });

  testWidgets('輸出路徑可恢復預設', (tester) async {
    const outputPath = 'C:/recordings/custom';
    await Preferences.setOutputDir(outputPath);

    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(find.text(outputPath), findsOneWidget);

    final restoreButton = _findFirstWidgetWithText(
      OutlinedButton,
      _restoreDefaultPathLabels,
    );
    await tester.scrollUntilVisible(
      restoreButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();

    expect(await Preferences.getOutputDir(), isNull);
    expect(_findFirstVisibleText(_outputPathUnsetLabels), findsOneWidget);
  });

  testWidgets('轉檔子開關跟著主開關', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    expect(
      tester
          .widget<Switch>(
            _findTileSwitchByLabels(_deleteSourceAfterConvertTitleLabels),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<Switch>(
            _findTileSwitchByLabels(_ffmpegAllowDuringRecordingTitleLabels),
          )
          .onChanged,
      isNull,
    );

    tester
        .widget<Switch>(_findTileSwitchByLabels(_convertToMp4TitleLabels))
        .onChanged!(true);
    await tester.pumpAndSettle();
    tester
        .widget<Switch>(
          _findTileSwitchByLabels(_deleteSourceAfterConvertTitleLabels),
        )
        .onChanged!(true);
    await tester.pumpAndSettle();

    await _closeSettings(tester);
    await _openSettings(tester);

    expect(
      tester
          .widget<Switch>(_findTileSwitchByLabels(_convertToMp4TitleLabels))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(
            _findTileSwitchByLabels(_deleteSourceAfterConvertTitleLabels),
          )
          .value,
      isTrue,
    );
    final env = await Preferences.getManagedEnvironmentSettings();
    expect(env['CONVERT_TO_MP4'], 'true');
    expect(env['DELETE_SOURCE_AFTER_CONVERT'], 'true');
  });

  testWidgets('microSD 的 flush 用寫入當下的同時錄製數', (tester) async {
    await tester.pumpWidget(const BilirecApp());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    _optionSliderByTitle(tester, _maxConcurrentRecordingsTitleLabels)
        .onChangeEnd
        ?.call(15);
    await tester.pumpAndSettle();

    tester
        .widget<Switch>(
          _findRowSwitchByLabels(_microSdWearProtectionTitleLabels),
        )
        .onChanged!(true);
    await tester.pumpAndSettle();

    final expectedFlush = '${computeFlushPeriodSecs(15)}';
    final env = await Preferences.getManagedEnvironmentSettings();
    expect(env['MAX_CONCURRENT_RECORDINGS'], '15');
    expect(env['SEQUENTIAL_WRITE'], 'true');
    expect(env['LIVE_STREAM_WRITER_FLUSH_PERIOD_SECS'], expectedFlush);
    expect(env['DANMAKU_WRITER_FLUSH_PERIOD_SECS'], expectedFlush);
  });
}
