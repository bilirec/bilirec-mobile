import 'package:bilirec/l10n/app_localizations.dart';

List<String> labelsForKey(String key) {
  final labels = <String>[];
  final seen = <String>{};

  for (final locale in AppLocalizations.supportedLocales) {
    final value = AppLocalizations(locale).tr(key);
    if (seen.add(value)) {
      labels.add(value);
    }
  }

  return List.unmodifiable(labels);
}

List<String> labelsForKeys(Iterable<String> keys) {
  final labels = <String>[];
  final seen = <String>{};

  for (final key in keys) {
    for (final value in labelsForKey(key)) {
      if (seen.add(value)) {
        labels.add(value);
      }
    }
  }

  return List.unmodifiable(labels);
}

String labelForKeyAndCode(String key, String localeCode) {
  final locale = AppLocaleConfig.localeForCode(localeCode);
  return AppLocalizations(locale).tr(key);
}

