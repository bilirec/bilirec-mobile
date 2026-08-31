import 'package:bilirec/shared/legacy_android_compatible.dart';
import 'package:flutter/material.dart';

typedef PermissionToastCallback = void Function(String message);

Future<bool> ensureExternalStoragePermissionWithPrompt({
  required BuildContext context,
  required String dialogTitle,
  required String dialogContent,
  required String confirmLabel,
  required String deniedToastMessage,
  required PermissionToastCallback showToast,
  String? targetPath,
  bool promptOnlyForExternalPath = false,
  bool showDeniedToastBeforePrompt = false,
  bool showDeniedToastAfterDenied = true,
}) async {
  if (promptOnlyForExternalPath) {
    final path = (targetPath ?? '').trim();
    if (path.isEmpty || !isExternalStorageDirectoryPath(path)) {
      return true;
    }
  }

  final granted = await hasExternalStoragePermissionFromVersion();
  if (granted) {
    return true;
  }

  if (!context.mounted) return false;

  if (showDeniedToastBeforePrompt) {
    showToast(deniedToastMessage);
  }

  final shouldRequestPermission = await _showPermissionDialog(
    context: context,
    dialogTitle: dialogTitle,
    dialogContent: dialogContent,
    confirmLabel: confirmLabel,
  );
  if (!shouldRequestPermission) {
    return false;
  }

  final requestedGranted = await requestExternalStoragePermissionFromVersion();
  if (!requestedGranted && showDeniedToastAfterDenied && context.mounted) {
    showToast(deniedToastMessage);
  }

  return requestedGranted;
}

Future<bool> _showPermissionDialog({
  required BuildContext context,
  required String dialogTitle,
  required String dialogContent,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(dialogTitle),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result == true;
}
