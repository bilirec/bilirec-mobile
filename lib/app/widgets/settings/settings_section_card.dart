import 'package:flutter/material.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    required this.children,
    this.icon,
    this.title,
    this.description,
    this.descriptionStyle,
    this.padding = const EdgeInsets.all(16),
    this.headerSpacing = 14,
    super.key,
  });

  final IconData? icon;
  final String? title;
  final String? description;
  final TextStyle? descriptionStyle;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasHeader = icon != null || title != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasHeader) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon),
                    const SizedBox(width: 8),
                  ],
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: descriptionStyle ??
                      theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (children.isNotEmpty) SizedBox(height: headerSpacing),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
