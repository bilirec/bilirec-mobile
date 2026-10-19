import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_sheet_toast.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';

class DevelopEnvironmentSection extends StatefulWidget {
  const DevelopEnvironmentSection({required this.enabled, super.key});

  final bool enabled;

  @override
  State<DevelopEnvironmentSection> createState() =>
      _DevelopEnvironmentSectionState();
}

class _DevelopEnvironmentSectionState extends State<DevelopEnvironmentSection> {
  Map<String, String>? _developEnvironmentSettings;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await Preferences.getDevelopEnvironmentSettings();
    if (!mounted) return;
    setState(() {
      _developEnvironmentSettings = settings;
    });
  }

  Future<void> _upsertEnvironmentSetting({
    required String key,
    required String value,
    String? replaceKey,
  }) async {
    final normalizedKey = key.trim();
    final normalizedValue = value.trim();
    if (normalizedKey.isEmpty) {
      if (!mounted) return;
      showSettingsToast(context, l10n.tr('environmentKeyRequired'));
      return;
    }

    final current = _developEnvironmentSettings ?? <String, String>{};
    final updated = <String, String>{...current};
    if (replaceKey != null && replaceKey != normalizedKey) {
      updated.remove(replaceKey);
    }
    updated[normalizedKey] = normalizedValue;
    await Preferences.setDevelopEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _developEnvironmentSettings = updated;
    });
  }

  Future<void> _showEnvironmentSettingDialog({String? initialKey}) async {
    final current = _developEnvironmentSettings ?? <String, String>{};
    final initialValue = initialKey == null ? '' : current[initialKey] ?? '';
    var keyText = initialKey ?? '';
    var valueText = initialValue;

    final result = await showDialog<_EnvironmentSettingInput>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            initialKey == null
                ? l10n.tr('addEnvironmentSetting')
                : l10n.tr('editEnvironmentSetting'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('env_key_input'),
                autofocus: true,
                textInputAction: TextInputAction.next,
                initialValue: keyText,
                onChanged: (value) => keyText = value,
                decoration: InputDecoration(
                  labelText: l10n.tr('environmentKeyLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('env_value_input'),
                textInputAction: TextInputAction.done,
                initialValue: valueText,
                onChanged: (value) => valueText = value,
                onFieldSubmitted: (_) {
                  Navigator.of(dialogContext).pop(
                    _EnvironmentSettingInput(
                      key: keyText,
                      value: valueText,
                    ),
                  );
                },
                decoration: InputDecoration(
                  labelText: l10n.tr('environmentValueLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  _EnvironmentSettingInput(
                    key: keyText,
                    value: valueText,
                  ),
                );
              },
              child: Text(l10n.tr('saveEnvironmentSetting')),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    await _upsertEnvironmentSetting(
      key: result.key,
      value: result.value,
      replaceKey: initialKey,
    );
  }

  Future<void> _removeEnvironmentSetting(String key) async {
    final current = _developEnvironmentSettings;
    if (current == null || !current.containsKey(key)) {
      return;
    }
    final updated = <String, String>{...current}..remove(key);
    await Preferences.setDevelopEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _developEnvironmentSettings = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _developEnvironmentSettings;
    if (settings == null) {
      return const SizedBox(height: 48);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final customEnvironmentEntries = settings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tr('developerSettingsTitle'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.tr('developerSectionDescription'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SettingsSectionCard(
          icon: Icons.code_outlined,
          title: l10n.tr('environmentSettingsTitle'),
          headerSpacing: 8,
          children: [
            SettingsHint(
              tone: SettingsHintTone.error,
              text: l10n.tr('environmentSettingsWarning'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  widget.enabled ? () => _showEnvironmentSettingDialog() : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.tr('addEnvironmentSetting')),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.tr('savedEnvironmentSettingsTitle'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (customEnvironmentEntries.isEmpty)
              Text(
                l10n.tr('environmentSettingsEmpty'),
                style: theme.textTheme.bodySmall,
              )
            else
              ...customEnvironmentEntries.map((entry) {
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    subtitle: Text(
                      entry.value.isEmpty
                          ? l10n.tr('environmentValueEmpty')
                          : entry.value,
                    ),
                    trailing: IconButton(
                      onPressed: widget.enabled
                          ? () => _removeEnvironmentSetting(entry.key)
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.tr('removeEnvironmentSetting'),
                    ),
                    onTap: widget.enabled
                        ? () => _showEnvironmentSettingDialog(
                            initialKey: entry.key)
                        : null,
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

class _EnvironmentSettingInput {
  const _EnvironmentSettingInput({
    required this.key,
    required this.value,
  });

  final String key;
  final String value;
}
