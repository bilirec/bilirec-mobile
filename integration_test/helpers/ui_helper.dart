import 'dart:async';

import 'package:bilirec/shared/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

Finder _findText(String label, {bool contains = false}) {
  return contains ? find.textContaining(label) : find.text(label);
}

String visibleLabelsSummary(Iterable<String> labels, {bool contains = false}) {
  final visible = labels
      .where((label) => _findText(label, contains: contains).evaluate().isNotEmpty)
      .toList();
  return visible.isEmpty ? '<none>' : visible.join(' | ');
}

bool isAnyLabelVisible(Iterable<String> labels, {bool contains = false}) {
  return labels.any(
      (label) => _findText(label, contains: contains).evaluate().isNotEmpty);
}

Finder findFirstVisibleText(
  Iterable<String> labels, {
  String? logTag,
  bool contains = false,
}) {
  for (final label in labels) {
    final finder = _findText(label, contains: contains);
    if (finder.evaluate().isNotEmpty) {
      if (logTag != null) {
        testLog(logTag, 'find text success: "$label"');
      }
      return finder;
    }
  }
  if (logTag != null) {
    testLog(logTag, 'find text fallback to first label: "${labels.first}"');
  }
  return _findText(labels.first, contains: contains);
}

Future<void> waitForAnyText(
  WidgetTester tester,
  Iterable<String> labels, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 400),
  String? logTag,
  bool contains = false,
}) async {
  if (logTag != null) {
    testLog(
      logTag,
      'wait any text start: labels=${labels.join(' / ')}, timeout=${timeout.inSeconds}s',
    );
  }

  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < maxTicks; i++) {
    if (isAnyLabelVisible(labels, contains: contains)) {
      if (logTag != null) {
        testLog(
          logTag,
          'wait any text done: visible=${visibleLabelsSummary(labels, contains: contains)}',
        );
      }
      return;
    }
    await tester.pump(step);
  }

  expect(
    isAnyLabelVisible(labels, contains: contains),
    isTrue,
    reason: '在 ${timeout.inSeconds} 秒內應看到 ${labels.join(' / ')} 其中之一',
  );
}

Future<void> tapButtonByLabels(
  WidgetTester tester, {
  required Type buttonType,
  required Iterable<String> labels,
}) async {
  Finder? actionButton;
  for (final label in labels) {
    final candidate = find.widgetWithText(buttonType, label);
    if (candidate.evaluate().isNotEmpty) {
      actionButton = candidate.first;
      break;
    }
  }

  expect(actionButton, isNotNull, reason: '應找到按鈕: ${labels.join(' / ')}');
  await tester.ensureVisible(actionButton!);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(actionButton, warnIfMissed: false);
}

Future<void> tapPowerButton(
  WidgetTester tester, {
  required Iterable<String> startLabels,
  required Iterable<String> stopLabels,
  String? logTag,
}) async {
  final startFinder = findFirstVisibleText(startLabels, logTag: logTag);
  if (startFinder.evaluate().isNotEmpty) {
    if (logTag != null) testLog(logTag, 'tap power button: tapping START');
    await tester.tap(startFinder.first);
    await tester.pump(const Duration(milliseconds: 150));
    return;
  }

  final stopFinder = findFirstVisibleText(stopLabels, logTag: logTag);
  if (stopFinder.evaluate().isNotEmpty) {
    if (logTag != null) testLog(logTag, 'tap power button: tapping STOP');
    await tester.tap(stopFinder.first);
    await tester.pump(const Duration(milliseconds: 150));
    return;
  }

  fail('找不到可點擊的啟動/停止按鈕');
}

Future<void> waitUntilPowerButtonStable(
  WidgetTester tester, {
  required Iterable<String> inFlightLabels,
  required Iterable<String> startLabels,
  required Iterable<String> stopLabels,
  Duration timeout = const Duration(seconds: 40),
  String? logTag,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final hasInFlight = isAnyLabelVisible(inFlightLabels);
    final hasStable = isAnyLabelVisible([...startLabels, ...stopLabels]);

    if (!hasInFlight && hasStable) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (logTag != null) testLog(logTag, 'wait power stable timeout');
  fail('等待啟停狀態穩定超時（${timeout.inSeconds}s）');
}

Finder? findConnectionCheckButton(Iterable<String> labels, {String? logTag}) {
  for (final label in labels) {
    final candidate = find.widgetWithText(OutlinedButton, label);
    if (candidate.evaluate().isNotEmpty) {
      if (logTag != null) {
        testLog(logTag,
            'found connection button label="$label" via widgetWithText');
      }
      return candidate.first;
    }

    final textFinder = find.text(label);
    if (textFinder.evaluate().isNotEmpty) {
      final buttonAncestor = find.ancestor(
        of: textFinder.first,
        matching: find.byType(OutlinedButton),
      );
      if (buttonAncestor.evaluate().isNotEmpty) {
        if (logTag != null) {
          testLog(logTag,
              'found connection button label="$label" via ancestor lookup');
        }
        return buttonAncestor.first;
      }
    }
  }
  return null;
}

Future<void> assertBackendConnectableFromUi(
  WidgetTester tester, {
  required Iterable<String> checkConnectionLabels,
  required Iterable<String> connectionFailedLabels,
  bool failIfButtonMissing = false,
  String? logTag,
}) async {
  if (isAnyLabelVisible(connectionFailedLabels, contains: true)) {
    fail('檢查系統服務連線顯示無法連線/無回應，判定測試失敗');
  }

  Finder? actionButton;
  for (var i = 0; i < 20; i++) {
    actionButton =
        findConnectionCheckButton(checkConnectionLabels, logTag: logTag);
    if (actionButton != null) break;
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (actionButton == null) {
    if (failIfButtonMissing) {
      fail('找不到「檢查系統服務連線」按鈕，無法驗證連線');
    }
    if (logTag != null) {
      testLog(logTag, 'connection button not found, skip active click check');
    }
    return;
  }

  await tester.ensureVisible(actionButton);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(actionButton, warnIfMissed: false);

  var toastShown = false;
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 500));

    if (isAnyLabelVisible(connectionFailedLabels, contains: true)) {
      fail('檢查系統服務連線顯示無法連線/無回應，判定測試失敗');
    }

    if (find.byType(AppToast).evaluate().isNotEmpty) {
      toastShown = true;
      break;
    }
  }

  if (failIfButtonMissing && !toastShown) {
    fail('未在預期時間看到連線檢查結果 toast');
  }
}

Future<void> ensureForegroundNotificationPermissionGranted({
  String? logTag,
  Duration requestTimeout = const Duration(minutes: 3),
}) async {
  final permission = await FlutterForegroundTaskPlatform.instance
      .checkNotificationPermission();

  if (permission == NotificationPermission.granted) {
    return;
  }

  if (logTag != null) {
    testLog(logTag,
        'foreground notification permission not granted, requesting permission...');
  }

  NotificationPermission granted;
  try {
    granted = await FlutterForegroundTaskPlatform.instance
        .requestNotificationPermission()
        .timeout(requestTimeout);
  } on TimeoutException {
    if (logTag != null) {
      testLog(logTag, 'notification permission request timeout');
    }
    fail('等待取得通知權限超時（三分鐘）失敗');
  }

  expect(
    granted,
    NotificationPermission.granted,
    reason:
        'Foreground notification permission is required but was not granted.',
  );
}

Future<void> shutdownServiceSafely(
  WidgetTester tester, {
  required Iterable<String> inFlightLabels,
  required Iterable<String> startLabels,
  required Iterable<String> stopLabels,
  String? logTag,
}) async {
  final hasInFlight = isAnyLabelVisible(inFlightLabels);
  if (hasInFlight) {
    await waitUntilPowerButtonStable(
      tester,
      inFlightLabels: inFlightLabels,
      startLabels: startLabels,
      stopLabels: stopLabels,
      logTag: logTag,
    );
  }

  if (findFirstVisibleText(stopLabels, logTag: logTag).evaluate().isNotEmpty) {
    await tapPowerButton(
      tester,
      startLabels: startLabels,
      stopLabels: stopLabels,
      logTag: logTag,
    );
    await waitUntilPowerButtonStable(
      tester,
      inFlightLabels: inFlightLabels,
      startLabels: startLabels,
      stopLabels: stopLabels,
      logTag: logTag,
    );
  }
}

void assertAppAlive({
  required Iterable<String> controlLabels,
  String reason = 'App UI 已失去控制區，疑似閃退',
}) {
  expect(isAnyLabelVisible(controlLabels), isTrue, reason: reason);
}
