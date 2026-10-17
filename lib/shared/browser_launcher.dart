import 'package:android_intent_plus/android_intent.dart';
import 'package:bilirec/app/widgets/external_browser_picker_sheet.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/browser_packages.dart';
import 'package:bilirec/shared/debugger.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Stored preference value for the system default browser handler.
const String externalBrowserChoiceSystem = 'system';

Future<bool> launchUrlInSystemBrowser(Uri uri) => _launchSystemDefault(uri);

/// [null] when the user dismissed the browser picker without choosing.
Future<bool?> openRecordingFrontendUrl(BuildContext context, Uri uri) async {
  if (await _tryLaunchInstalledPwa(uri)) {
    return true;
  }

  var choice = await Preferences.getExternalBrowserChoice();
  if (choice == null) {
    if (!context.mounted) {
      return false;
    }
    final picked = await showExternalBrowserPickerSheet(
      context,
      promptToRemember: true,
    );
    if (picked == null) {
      return null;
    }
    choice = picked.choice;
    if (picked.remember) {
      await Preferences.setExternalBrowserChoice(choice);
    }
    final recoveryContext = context.mounted ? context : null;
    return _launchAndroidWithChoice(
      uri,
      choice,
      context: recoveryContext,
      allowRecoveryPicker: true,
    );
  }

  final recoveryContext = context.mounted ? context : null;
  return _launchAndroidWithChoice(
    uri,
    choice,
    context: recoveryContext,
    allowRecoveryPicker: true,
  );
}

Future<bool> _launchAndroidWithChoice(
  Uri uri,
  String choice, {
  BuildContext? context,
  required bool allowRecoveryPicker,
}) async {
  if (choice == externalBrowserChoiceSystem) {
    return _launchSystemDefault(uri);
  }

  try {
    final intent = AndroidIntent(
      action: 'action_view',
      data: uri.toString(),
      package: choice,
    );
    await intent.launch();
    return true;
  } catch (e) {
    debugLog('Failed to open url in package $choice: $e');
    await Preferences.clearExternalBrowserChoice();
    if (!allowRecoveryPicker || context == null || !context.mounted) {
      return _launchSystemDefault(uri);
    }
    final picked = await showExternalBrowserPickerSheet(context);
    if (picked == null) {
      return _launchSystemDefault(uri);
    }
    await Preferences.setExternalBrowserChoice(picked.choice);
    return _launchAndroidWithChoice(
      uri,
      picked.choice,
      context: null,
      allowRecoveryPicker: false,
    );
  }
}

/// Opens [uri] only when a non-browser app (e.g. an installed PWA/WebAPK)
/// handles it; returns false when none does.
Future<bool> _tryLaunchInstalledPwa(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
  } catch (e) {
    debugLog('Failed to open url in non-browser app: $e');
    return false;
  }
}

Future<bool> _launchSystemDefault(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugLog('Failed to open url externally: $e');
    return false;
  }
}

String externalBrowserDisplayLabel({
  required AppLocalizations l10n,
  required String? storedChoice,
  required List<HttpsBrowserInfo> installedBrowsers,
}) {
  if (storedChoice == null) {
    return l10n.tr('externalBrowserNotChosen');
  }
  if (storedChoice == externalBrowserChoiceSystem) {
    return l10n.tr('externalBrowserSystemDefault');
  }
  for (final browser in installedBrowsers) {
    if (browser.packageName == storedChoice) {
      return browser.label;
    }
  }
  return l10n.tr(
    'externalBrowserUnavailable',
    params: {'name': storedChoice},
  );
}
