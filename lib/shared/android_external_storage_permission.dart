import 'dart:io';

import 'package:bilirec/shared/debugger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const _externalStorageMaxSdkInt = 29;

/// Returns true when external storage access is available or not required.
Future<bool> requestExternalStoragePermissionIfNeeded() async {
  if (!Platform.isAndroid) return true;

  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (sdkInt > _externalStorageMaxSdkInt) return true;

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
