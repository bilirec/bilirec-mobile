import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'test_helper.dart';

const _externalTestOutputDir = '/sdcard/Download/bilirec_it';
const _externalLogExportDir = '/sdcard/Download/bilirec_it_logs';

Future<bool> isAndroid10Only({String? logTag}) async {
  if (!Platform.isAndroid) return false;
  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (logTag != null) {
    testLog(logTag, 'device sdkInt=$sdkInt');
  }
  return sdkInt == 29;
}

Future<bool> needsLegacyStoragePermission() async {
  if (!Platform.isAndroid) return false;
  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  return sdkInt <= 29;
}

String defaultExternalTestOutputDir() => _externalTestOutputDir;

String defaultExternalLogExportDir() => _externalLogExportDir;

Future<void> ensureExternalDirExists(
  String path, {
  String? logTag,
}) async {
  if (!await isLegacyStorageGranted()) {
    if (logTag != null) {
      testLog(logTag, 'skip mkdir without storage permission: $path');
    }
    return;
  }

  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
    if (logTag != null) {
      testLog(logTag, 'created external dir: $path');
    }
  }
}

Future<bool> isLegacyStorageGranted() async {
  if (!await needsLegacyStoragePermission()) return true;
  return Permission.storage.isGranted;
}

Future<void> resetStorageTestDirs({String? logTag}) async {
  if (!await isLegacyStorageGranted()) {
    return;
  }

  for (final path in [_externalTestOutputDir, _externalLogExportDir]) {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        if (logTag != null) {
          testLog(logTag, 'removed external dir: $path');
        }
      }
    } catch (e) {
      if (logTag != null) {
        testLog(logTag, 'reset storage dir skipped: $path error=$e');
      }
    }
  }
}
