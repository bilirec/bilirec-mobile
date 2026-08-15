import 'package:flutter/material.dart';

enum SettingsHintTone {
  neutral,
  warning,
  error,
}

class SettingsHint extends StatelessWidget {
  const SettingsHint({
    required this.text,
    this.tone = SettingsHintTone.neutral,
    this.icon,
    super.key,
  });

  final String text;
  final SettingsHintTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color toneColor;
    final IconData defaultIcon;

    switch (tone) {
      case SettingsHintTone.neutral:
        toneColor = colorScheme.onSurfaceVariant;
        defaultIcon = Icons.info_outline;
      case SettingsHintTone.warning:
        toneColor = Colors.amber.shade700;
        defaultIcon = Icons.info_outline;
      case SettingsHintTone.error:
        toneColor = colorScheme.error;
        defaultIcon = Icons.warning_amber_rounded;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon ?? defaultIcon,
          size: 16,
          color: toneColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: toneColor,
            ),
          ),
        ),
      ],
    );
  }
}
