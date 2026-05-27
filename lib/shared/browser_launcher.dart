import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bilirec/shared/debugger.dart';

const String _chromePackageName = 'com.android.chrome';

Future<bool> openUrlPreferChrome(Uri uri) async {
  if (Platform.isAndroid) {
    try {
      final launchedAsPwa = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );

      if (launchedAsPwa) {
        return true;
      }

      final intent = AndroidIntent(
        action: 'action_view',
        data: uri.toString(),
        package: _chromePackageName,
      );

      final canResolve = await intent.canResolveActivity() ?? false;
      if (canResolve) {
        await intent.launch();
        return true;
      }
    } catch (e) {
      debugLog('Failed to open Chrome intent: $e');
    }
  }

  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugLog('Failed to open url externally: $e');
    return false;
  }
}

