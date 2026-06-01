import 'package:bilirec/l10n/app_localizations.dart';

List<String> labelsForKey(String key) {
  final labels = <String>[];
  final seen = <String>{};

  for (final locale in AppLocalizations.supportedLocales) {
    final label = AppLocalizations(locale).tr(key);
    if (seen.add(label)) {
      labels.add(label);
    }
  }

  return List.unmodifiable(labels);
}

List<String> labelsForKeys(Iterable<String> keys) {
  final labels = <String>[];
  final seen = <String>{};

  for (final key in keys) {
    for (final label in labelsForKey(key)) {
      if (seen.add(label)) {
        labels.add(label);
      }
    }
  }

  return List.unmodifiable(labels);
}

