// ignore_for_file: use_super_parameters

import 'package:bilirec/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class HomePageLanguageMenu extends StatelessWidget {
  const HomePageLanguageMenu({
    super.key,
    required this.currentLanguageCode,
    required this.onSelected,
  });

  final String currentLanguageCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final simplifiedLabel = l10n.tr('languageSimplified');
    final traditionalLabel = l10n.tr('languageTraditional');

    return PopupMenuButton<String>(
      tooltip: l10n.tr('languageMenuTooltip'),
      initialValue: currentLanguageCode,
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: AppLocaleConfig.traditionalCode,
          child: Text(traditionalLabel),
        ),
        PopupMenuItem<String>(
          value: AppLocaleConfig.simplifiedCode,
          child: Text(simplifiedLabel),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: Text(
            currentLanguageCode == AppLocaleConfig.simplifiedCode
                ? simplifiedLabel
                : traditionalLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
