import 'package:bilirec/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

export 'package:bilirec/app/widgets/settings/sections/settings_drawer_sheet.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.settings),
            label: Text(l10n.tr('settings')),
          ),
        ),
      ),
    );
  }
}
