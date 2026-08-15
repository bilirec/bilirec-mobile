import 'package:bilirec/app/widgets/settings/settings_slider_math.dart';
import 'package:flutter/material.dart';

class SettingsOptionSlider extends StatelessWidget {
  const SettingsOptionSlider({
    required this.title,
    required this.description,
    required this.options,
    required this.value,
    required this.valueLabel,
    required this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
    this.hint,
    super.key,
  });

  final String title;
  final String description;
  final List<int> options;
  final int value;
  final String valueLabel;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;
  final bool enabled;
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final divisions = options.length > 1 ? options.length - 1 : 1;
    final sliderValue = sliderFromOption(options, value);

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
          hint!,
        ],
        const SizedBox(height: 6),
        Text(
          valueLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Slider(
          value: sliderValue,
          min: 0,
          max: (options.length - 1).toDouble(),
          divisions: divisions,
          label: valueLabel,
          onChanged: enabled && onChanged != null
              ? (v) => onChanged!(optionFromSlider(options, v))
              : null,
          onChangeEnd: enabled && onChangeEnd != null
              ? (v) => onChangeEnd!(optionFromSlider(options, v))
              : null,
        ),
      ],
    );
  }
}
