import 'package:flutter/material.dart';

class SettingsSegmentedField<T> extends StatelessWidget {
  const SettingsSegmentedField({
    required this.title,
    required this.description,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.hint,
    this.enabled = true,
    Key? key,
  })  : segmentedKey = key,
        super(key: null);

  final Key? segmentedKey;
  final String title;
  final String description;
  final String? hint;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onSelectionChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodySmall,
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SegmentedButton<T>(
          key: segmentedKey,
          segments: segments,
          selected: {selected},
          onSelectionChanged: enabled && onSelectionChanged != null
              ? (selection) => onSelectionChanged!(selection.first)
              : null,
        ),
      ],
    );
  }
}
