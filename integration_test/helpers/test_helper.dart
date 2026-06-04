import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_method_channel.dart';
import 'package:path_provider/path_provider.dart';

void testLog(String tag, String message) {
  debugPrint('[$tag][${DateTime.now().toIso8601String()}] $message');
}

Future<void> printBootstrapLogsIfAny({
  required String scenario,
  String? logTag,
}) async {
  final appSupportDir = await getApplicationSupportDirectory();
  final sourceDir = Directory(appSupportDir.path);
  if (!await sourceDir.exists()) {
    return;
  }

  final entities = await sourceDir.list().toList();
  final logFiles = entities.whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return name.startsWith('bootstrap') && name.endsWith('.log');
  }).toList();

  if (logFiles.isEmpty) {
    return;
  }

  final tag = logTag ?? 'BOOTSTRAP_LOG';
  logFiles.sort((a, b) => a.path.compareTo(b.path));
  testLog(tag, '===== bootstrap.log dump ($scenario) =====');
  for (final file in logFiles) {
    testLog(tag, '--- file: ${file.path} ---');
    try {
      final lines = await file.readAsLines();
      for (final line in lines) {
        testLog(tag, line);
      }
    } catch (e) {
      testLog(tag, 'bootstrap.log read failed: path=${file.path} error=$e');
    }
  }
  testLog(tag, '===== end bootstrap.log dump ($scenario) =====');
}

class BatteryBypassForegroundTaskPlatform
    extends MethodChannelFlutterForegroundTask {
  @override
  Future<bool> get isIgnoringBatteryOptimizations async => true;
}

class PermissionGrantedForegroundTaskPlatform
    extends BatteryBypassForegroundTaskPlatform {
  @override
  Future<NotificationPermission> checkNotificationPermission() async {
    return NotificationPermission.granted;
  }

  @override
  Future<NotificationPermission> requestNotificationPermission() async {
    return NotificationPermission.granted;
  }
}

class BatteryDialogForegroundTaskPlatform
    extends MethodChannelFlutterForegroundTask {
  @override
  Future<bool> get isIgnoringBatteryOptimizations async => false;

  @override
  Future<NotificationPermission> checkNotificationPermission() async {
    return NotificationPermission.granted;
  }

  @override
  Future<NotificationPermission> requestNotificationPermission() async {
    return NotificationPermission.granted;
  }
}

bool isCiEnv() {
  // Prefer --dart-define CI value because process env may not propagate into emulator test runtime.
  final defineRaw = const String.fromEnvironment('CI').trim().toLowerCase();
  final raw = defineRaw.isNotEmpty
      ? defineRaw
      : (Platform.environment['CI']?.trim().toLowerCase() ?? '');
  return raw == '1' || raw == 'true' || raw == 'yes';
}

Duration recordingDurationByCi({
  int localMinutes = 3,
  int ciMinutes = 15,
}) {
  return Duration(minutes: isCiEnv() ? ciMinutes : localMinutes);
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String asString(dynamic value) => value?.toString() ?? '';
