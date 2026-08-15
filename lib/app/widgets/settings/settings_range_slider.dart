import 'package:flutter/material.dart';

class SettingsRangeSlider extends StatelessWidget {
  const SettingsRangeSlider({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
    this.dimmedWhenDisabled = false,
    this.hint,
    super.key,
  });

  final String title;
  final String description;
  final int value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;
  final bool enabled;
  final bool dimmedWhenDisabled;
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: (!enabled && dimmedWhenDisabled)
                ? colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: (!enabled && dimmedWhenDisabled)
                ? colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          hint!,
        ],
        const SizedBox(height: 6),
        Text(
          valueLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          // Keep line metrics stable between different label texts.
          strutStyle: StrutStyle(
            fontSize: theme.textTheme.bodySmall?.fontSize,
            height: 1.25,
            forceStrutHeight: true,
          ),
        ),
        Slider(
          value: value.toDouble().clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: enabled && onChanged != null
              ? (v) => onChanged!(v.round())
              : null,
          onChangeEnd: enabled && onChangeEnd != null
              ? (v) => onChangeEnd!(v.round())
              : null,
        ),
      ],
    );

    if (dimmedWhenDisabled) {
      return Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: content,
      );
    }

    return content;
  }
}
