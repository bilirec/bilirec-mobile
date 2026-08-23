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
    final kind = prompt.kind;
    final showEnableBoot =
        kind == UnexpectedStopPromptKind.enableAutoRunOnBoot;
    final showSetupGuide = kind == UnexpectedStopPromptKind.openOemDocs ||
        kind == UnexpectedStopPromptKind.rebootNotice;

    final titleKey = switch (kind) {
      UnexpectedStopPromptKind.enableAutoRunOnBoot =>
        'unexpectedStopRebootTitle',
      UnexpectedStopPromptKind.rebootNotice =>
        'unexpectedStopBlockedBootTitle',
      UnexpectedStopPromptKind.openOemDocs => 'unexpectedStopKillTitle',
    };
    final bodyKey = switch (kind) {
      UnexpectedStopPromptKind.enableAutoRunOnBoot =>
        'unexpectedStopRebootBody',
      UnexpectedStopPromptKind.rebootNotice =>
        'unexpectedStopBlockedBootBody',
      UnexpectedStopPromptKind.openOemDocs => 'unexpectedStopKillBody',
    };

    return AlertDialog(
      title: Text(l10n.tr(titleKey)),
      content: Text(l10n.tr(bodyKey)),
      actionsPadding: EdgeInsets.zero,
      buttonPadding: EdgeInsets.zero,
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showEnableBoot || showSetupGuide) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      showEnableBoot
                          ? UnexpectedStopDialogAction.enableAutoRunOnBoot
                          : UnexpectedStopDialogAction.openOemDocs,
                    ),
                    child: Text(
                      l10n.tr(
                        showEnableBoot
                            ? 'unexpectedStopRebootEnableBoot'
                            : 'unexpectedStopViewSetupGuide',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 1),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(UnexpectedStopDialogAction.mute),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                        ),
                        child: Text(l10n.tr('unexpectedStopDontRemind')),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(UnexpectedStopDialogAction.dismiss),
                        child: Text(l10n.tr('unexpectedStopDismiss')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
