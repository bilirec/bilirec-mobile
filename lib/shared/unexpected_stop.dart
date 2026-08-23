import 'package:bilirec/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum UnexpectedStopCause { reboot, backgroundKill }

enum UnexpectedStopPromptKind {
  enableAutoRunOnBoot,
  openOemDocs,
  rebootNotice,
}

class UnexpectedStopPrompt {
  const UnexpectedStopPrompt({
    required this.cause,
    required this.kind,
  });

  final UnexpectedStopCause cause;
  final UnexpectedStopPromptKind kind;
}

UnexpectedStopCause? classifyUnexpectedStop({
  required bool serviceRunning,
  required bool intendedRunning,
  required bool stoppedByUser,
  required bool promptMuted,
  required int? lastStartId,
  required int? consumedStartId,
  String? lastBootId,
  String? currentBootId,
}) {
  if (serviceRunning ||
      !intendedRunning ||
      stoppedByUser ||
      promptMuted ||
      lastStartId == null ||
      consumedStartId == lastStartId) {
    return null;
  }

  if (_bootIdChanged(lastBootId, currentBootId)) {
    return UnexpectedStopCause.reboot;
  }
  return UnexpectedStopCause.backgroundKill;
}

bool _bootIdChanged(String? lastBootId, String? currentBootId) {
  if (lastBootId == null ||
      lastBootId.isEmpty ||
      currentBootId == null ||
      currentBootId.isEmpty) {
    return false;
  }
  return lastBootId != currentBootId;
}

UnexpectedStopPrompt? resolveUnexpectedStopPrompt({
  required UnexpectedStopCause? cause,
  required bool autoRunOnBootEnabled,
}) {
  if (cause == null) {
    return null;
  }
  if (cause == UnexpectedStopCause.reboot && !autoRunOnBootEnabled) {
    return const UnexpectedStopPrompt(
      cause: UnexpectedStopCause.reboot,
      kind: UnexpectedStopPromptKind.enableAutoRunOnBoot,
    );
  }
  if (cause == UnexpectedStopCause.reboot) {
    return const UnexpectedStopPrompt(
      cause: UnexpectedStopCause.reboot,
      kind: UnexpectedStopPromptKind.rebootNotice,
    );
  }
  return UnexpectedStopPrompt(
    cause: cause,
    kind: UnexpectedStopPromptKind.openOemDocs,
  );
}

String androidMainlandDocsUrl(Locale locale) {
  final path =
      AppLocaleConfig.codeForLocale(locale) == AppLocaleConfig.simplifiedCode
          ? 'zh-cn'
          : 'zh-tw';
  return 'https://www.bilirec.org/$path/guides/android-mainland/';
}
