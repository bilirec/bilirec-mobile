int optionFromSlider(List<int> options, double sliderValue) {
  if (options.isEmpty) return 0;
  final index = sliderValue.round().clamp(0, options.length - 1);
  return options[index];
}

double sliderFromOption(List<int> options, int value) {
  final index = options.indexOf(value);
  return (index >= 0 ? index : 0).toDouble();
}
