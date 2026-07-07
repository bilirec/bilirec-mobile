import 'dart:io';

import 'package:bilirec/shared/debugger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

const _externalStorageMaxSdkInt = 29;

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

    final result = await Permission.manageExternalStorage.request();
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
