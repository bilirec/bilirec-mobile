import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:bilirec/shared/debugger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

const _externalStorageMaxSdkInt = 29;
const _androidPackageName = 'org.bilirec.bilirec';

bool isExternalStorageDirectoryPath(String path) {
  final normalized = path.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) return false;

  return normalized.startsWith('/storage/') ||
      normalized == '/sdcard' ||
      normalized.startsWith('/sdcard/') ||
      normalized.startsWith('/mnt/media_rw/') ||
      normalized.startsWith('/mnt/sdcard/') ||
      normalized.startsWith('/mnt/user/');
}

Future<bool> hasExternalStoragePermissionFromVersion() async {
  if (!Platform.isAndroid) return true;

  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (sdkInt > _externalStorageMaxSdkInt) {
    return Permission.manageExternalStorage.isGranted;
  }

  return Permission.storage.isGranted;
}

/// Returns true when external storage access is available or not required.
Future<bool> requestExternalStoragePermissionFromVersion() async {
  if (!Platform.isAndroid) return true;

  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (sdkInt > _externalStorageMaxSdkInt) {
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) {
      debugLog('Manage external storage permission already granted');
      return true;
    }

    await _openManageExternalStorageSettings();
    final result = await Permission.manageExternalStorage.status;
    debugLog(
      result.isGranted
          ? 'Manage external storage permission granted'
          : 'Manage external storage permission denied: $result',
    );
    return result.isGranted;
  }

  final status = await Permission.storage.status;
  if (status.isGranted) {
    debugLog('External storage permission already granted');
    return true;
  }

  final result = await Permission.storage.request();
  debugLog(
    result.isGranted
        ? 'External storage permission granted'
        : 'External storage permission denied: $result',
  );
  return result.isGranted;
}

Future<void> _openManageExternalStorageSettings() async {
  final resumed = Completer<void>();
  final observer = _ExternalStorageSettingsLifecycleObserver(resumed);
  WidgetsBinding.instance.addObserver(observer);

  try {
    await AndroidIntent(
      action: 'android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION',
      data: 'package:$_androidPackageName',
    ).launch();
    await resumed.future;
  } finally {
    WidgetsBinding.instance.removeObserver(observer);
  }
}

final class _ExternalStorageSettingsLifecycleObserver
    with WidgetsBindingObserver {
  _ExternalStorageSettingsLifecycleObserver(this._resumed);

  final Completer<void> _resumed;
  bool _leftForeground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _leftForeground = true;
      case AppLifecycleState.resumed:
        if (_leftForeground && !_resumed.isCompleted) {
          _resumed.complete();
        }
      case AppLifecycleState.detached:
        break;
    }
  }
}

Future<bool> canWriteToDirectoryPath(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;

  File? probeFile;
  try {
    final directory = Directory(trimmed);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    probeFile = File(
      '${directory.path}${Platform.pathSeparator}.bilirec_write_probe_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await probeFile.writeAsString('probe', flush: true);
    return true;
  } catch (e) {
    debugLog('Directory write probe failed for "$path": $e');
    return false;
  } finally {
    if (probeFile != null) {
      try {
        if (await probeFile.exists()) {
          await probeFile.delete();
        }
      } catch (_) {
        // Ignore cleanup failure for probe files.
      }
    }
  }
}

Future<bool> ensureDirectoryWritableWithPermissionFromVersion(
    String path) async {
  if (await canWriteToDirectoryPath(path)) {
    return true;
  }

  final granted = await requestExternalStoragePermissionFromVersion();
  if (!granted) {
    return false;
  }

  return canWriteToDirectoryPath(path);
}

Future<List<ForegroundServiceTypes>>
    getForegroundServiceTypesFromVersion() async {
  if (!Platform.isAndroid) return [];

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;

  if (sdkInt >= 34) {
    return [ForegroundServiceTypes.specialUse];
  } else if (sdkInt >= 29) {
    return [ForegroundServiceTypes.dataSync];
  }

  return [];
}
