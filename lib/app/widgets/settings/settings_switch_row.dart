import 'package:flutter/material.dart';

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.titleStyle,
    this.descriptionStyle,
    this.spacing = 8,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final double spacing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: titleStyle ?? theme.textTheme.titleMedium,
              ),
              SizedBox(height: spacing),
              Text(
                description,
                style: descriptionStyle ?? theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}
