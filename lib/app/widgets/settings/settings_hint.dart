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
    this.inlineLinkLabel,
    this.onInlineLinkTap,
    this.inlineLinkPlaceholder = '{link}',
    super.key,
  });

  final String text;
  final SettingsHintTone tone;
  final IconData? icon;
  final String? inlineLinkLabel;
  final VoidCallback? onInlineLinkTap;
  final String inlineLinkPlaceholder;

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

    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: toneColor,
    );

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
          child: _buildMessage(context, baseStyle, toneColor),
        ),
      ],
    );
  }

  Widget _buildMessage(
    BuildContext context,
    TextStyle? baseStyle,
    Color toneColor,
  ) {
    final linkLabel = inlineLinkLabel;
    final onLinkTap = onInlineLinkTap;
    if (linkLabel == null ||
        onLinkTap == null ||
        !text.contains(inlineLinkPlaceholder)) {
      return Text(text, style: baseStyle);
    }

    final parts = text.split(inlineLinkPlaceholder);
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: parts.first),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onLinkTap,
              child: Text(linkLabel, style: linkStyle),
            ),
          ),
          if (parts.length > 1)
            TextSpan(text: parts.sublist(1).join(inlineLinkPlaceholder)),
        ],
      ),
    );
  }
}
