import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/unexpected_stop.dart';
import 'package:flutter/material.dart';

enum UnexpectedStopDialogAction {
  dismiss,
  mute,
  enableAutoRunOnBoot,
  openOemDocs,
}

class UnexpectedStopDialog extends StatelessWidget {
  const UnexpectedStopDialog({
    required this.prompt,
    super.key,
  });

  final UnexpectedStopPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isBootPrompt =
        prompt.kind == UnexpectedStopPromptKind.enableAutoRunOnBoot;
    final isRebootBlocked =
        !isBootPrompt && prompt.cause == UnexpectedStopCause.reboot;

    final titleKey = isBootPrompt
        ? 'unexpectedStopRebootTitle'
        : (isRebootBlocked
            ? 'unexpectedStopBlockedBootTitle'
            : 'unexpectedStopKillTitle');
    final bodyKey = isBootPrompt
        ? 'unexpectedStopRebootBody'
        : (isRebootBlocked
            ? 'unexpectedStopBlockedBootBody'
            : 'unexpectedStopKillBody');
    final primaryKey = isBootPrompt
        ? 'unexpectedStopRebootEnableBoot'
        : 'unexpectedStopViewSetupGuide';

    return AlertDialog(
      title: Text(l10n.tr(titleKey)),
      content: Text(l10n.tr(bodyKey)),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                isBootPrompt
                    ? UnexpectedStopDialogAction.enableAutoRunOnBoot
                    : UnexpectedStopDialogAction.openOemDocs,
              ),
              child: Text(l10n.tr(primaryKey)),
            ),
            if (isBootPrompt)
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pop(UnexpectedStopDialogAction.openOemDocs),
                child: Text(l10n.tr('unexpectedStopViewSetupGuide')),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop(UnexpectedStopDialogAction.mute),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  child: Text(l10n.tr('unexpectedStopDontRemind')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop(UnexpectedStopDialogAction.dismiss),
                  child: Text(l10n.tr('unexpectedStopDismiss')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
