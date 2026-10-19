import 'dart:async';

import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/app_update_service.dart';
import 'package:flutter/material.dart';

enum _SignatureMismatchDialogAction { openGithub, installAnyway, dismiss }

class AppUpdatePrompt {
  AppUpdatePrompt({
    required this.context,
    required this.l10n,
    required this.service,
  });

  final BuildContext context;
  final AppLocalizations l10n;
  final AppUpdateService service;

  bool _updateDialogVisible = false;
  bool _hasCheckedStartupUpdate = false;

  bool get mounted => context.mounted;

  Future<void> checkOnStartup() async {
    if (_hasCheckedStartupUpdate || !mounted) {
      return;
    }
    _hasCheckedStartupUpdate = true;

    final update = await service.checkForUpdate();
    if (!mounted || update == null || _updateDialogVisible) {
      return;
    }

    _updateDialogVisible = true;
    final displayVersion = 'v${update.version}';
    final releaseNote = update.releaseNote.trim();
    final contentText = releaseNote.isEmpty
        ? l10n.tr('updateDialogContent', params: {'version': displayVersion})
        : releaseNote;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final textTheme = Theme.of(dialogContext).textTheme;
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.tr('updateDialogTitle',
                      params: {'version': displayVersion}),
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.tr('updateDialogContent',
                      params: {'version': displayVersion}),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        colorScheme.secondaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.secondary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          contentText,
                          textAlign: TextAlign.start,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _runUpdateNowFlow(update);
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: Text(l10n.tr('updateDialogUpdateNow')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(l10n.tr('updateDialogLater')),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () async {
                      final dialogNavigator = Navigator.of(dialogContext);
                      await service.skipReminderForVersion(
                        update.version,
                      );
                      if (!mounted) return;
                      dialogNavigator.pop();
                    },
                    icon: const Icon(Icons.skip_next_rounded, size: 16),
                    label: Text(l10n.tr('updateDialogSkipVersion')),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      textStyle: textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    _updateDialogVisible = false;
  }

  Future<void> _runUpdateNowFlow(AppUpdateCandidate update) async {
    if (!mounted) return;
    showAppToast(context, l10n.tr('updateDownloadStarted'));

    final progressNotifier = ValueNotifier<double?>(null);
    var progressDisposed = false;
    final resultCompleter = Completer<AppUpdateExecutionResult>();
    var startedOperation = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogNavigator = Navigator.of(dialogContext);
        if (!startedOperation) {
          startedOperation = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            AppUpdateExecutionResult result = AppUpdateExecutionResult.failed;
            try {
              result = await service.performUpdateWithFallback(
                update,
                onDownloadProgress: (received, total) {
                  if (progressDisposed) {
                    return;
                  }
                  if (total <= 0) {
                    progressNotifier.value = null;
                    return;
                  }
                  final ratio = received / total;
                  progressNotifier.value = ratio.clamp(0.0, 1.0);
                },
              );
            } catch (_) {
              result = AppUpdateExecutionResult.failed;
            } finally {
              if (!resultCompleter.isCompleted) {
                resultCompleter.complete(result);
              }
              if (dialogNavigator.mounted && dialogNavigator.canPop()) {
                dialogNavigator.pop();
              }
            }
          });
        }

        return PopScope(
          canPop: false,
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: ValueListenableBuilder<double?>(
                valueListenable: progressNotifier,
                builder: (context, progress, _) {
                  final colorScheme = Theme.of(context).colorScheme;
                  final textTheme = Theme.of(context).textTheme;
                  final progressPercent = progress == null
                      ? null
                      : (progress * 100).clamp(0, 100).toStringAsFixed(0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_download_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.tr('updateProgressDialogTitle'),
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tr('updateProgressDialogHint'),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    progressPercent == null
                                        ? l10n
                                            .tr('updateProgressDialogPreparing')
                                        : l10n.tr('updateProgressDialogPercent',
                                            params: {
                                                'progress': progressPercent
                                              }),
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    final result = await resultCompleter.future;
    progressDisposed = true;
    progressNotifier.dispose();

    if (!mounted) {
      return;
    }
    switch (result) {
      case AppUpdateExecutionResult.installLaunched:
        showAppToast(context, l10n.tr('updateInstallPromptHint'));
        break;
      case AppUpdateExecutionResult.signatureMismatch:
        await _showSignatureMismatchDialog(update);
        break;
      case AppUpdateExecutionResult.releasePageOpened:
        showAppToast(context, l10n.tr('updateOpenReleaseFallbackHint'));
        break;
      case AppUpdateExecutionResult.failed:
        showAppToast(context, l10n.tr('updateOpenReleaseFailed'));
        break;
    }
  }

  Future<void> _showSignatureMismatchDialog(AppUpdateCandidate update) async {
    if (!mounted) return;

    final action = await showDialog<_SignatureMismatchDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final textTheme = Theme.of(dialogContext).textTheme;
        return PopScope(
          canPop: false,
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gpp_bad_rounded,
                        color: colorScheme.onErrorContainer,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.tr('updateSignatureMismatchTitle'),
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tr('updateSignatureMismatchContent'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(
                      _SignatureMismatchDialogAction.openGithub,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(l10n.tr('updateSignatureMismatchOpenGithub')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(
                      _SignatureMismatchDialogAction.installAnyway,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(l10n.tr('updateSignatureMismatchInstallAnyway')),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(
                      _SignatureMismatchDialogAction.dismiss,
                    ),
                    child: Text(l10n.tr('updateSignatureMismatchDismiss')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _SignatureMismatchDialogAction.openGithub:
        final opened = await service.openReleasePage(update.releasePageUrl);
        if (!opened && mounted) {
          showAppToast(context, l10n.tr('updateOpenReleaseFailed'));
        }
      case _SignatureMismatchDialogAction.installAnyway:
        final launched = await service.installDownloadedApk(update.version);
        if (!mounted) {
          return;
        }
        if (launched) {
          showAppToast(context, l10n.tr('updateInstallPromptHint'));
        } else {
          showAppToast(context, l10n.tr('updateOpenReleaseFailed'));
        }
      case _SignatureMismatchDialogAction.dismiss:
        break;
    }
  }
}
