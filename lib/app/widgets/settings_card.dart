import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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

class SettingsDrawerSheet extends StatefulWidget {
  const SettingsDrawerSheet({
    required this.scrollController,
    required this.controlsEnabled,
    required this.onClose,
    super.key,
  });

  final ScrollController scrollController;
  final bool controlsEnabled;
  final VoidCallback onClose;

  @override
  State<SettingsDrawerSheet> createState() => _SettingsDrawerSheetState();
}

class _SettingsDrawerSheetState extends State<SettingsDrawerSheet> {
  bool _useSsePush = false;
  bool _useAntiSleep = false;
  Map<String, String> _environmentSettings = <String, String>{};

  final TextEditingController _outputDirController = TextEditingController();

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final outputPath = await Preferences.getOutputDir() ?? '';
    final useSsePush = await Preferences.getEnableSsePush();
    final useAntiSleep = await Preferences.getEnableAntiSleep();
    final environmentSettings = await Preferences.getEnvironmentSettings();
    if (!mounted) return;
    _outputDirController.text = outputPath;
    setState(() {
      _useSsePush = useSsePush;
      _useAntiSleep = useAntiSleep;
      _environmentSettings = environmentSettings;
    });
  }

  @override
  void dispose() {
    _outputDirController.dispose();
    super.dispose();
  }

  Future<String?> _browseBasePath() async {
    final currentDir = _outputDirController.text.trim();
    final initialDir = currentDir.isNotEmpty ? currentDir : null;

    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.tr('selectOutputPath'),
      initialDirectory: initialDir,
    );

    if (selected == null || !mounted) return null;

    setState(() {
      _outputDirController.text = selected;
    });

    await Preferences.setOutputDir(selected);
    if (!mounted) return null;
    return selected;
  }

  Future<void> _setSsePushEnabled(bool enabled) async {
    await Preferences.setEnableSsePush(enabled);
    if (!mounted) return;
    setState(() {
      _useSsePush = enabled;
    });
  }

  Future<void> _setAntiSleepEnabled(bool enabled) async {
    await Preferences.setEnableAntiSleep(enabled);
    if (!mounted) return;
    setState(() {
      _useAntiSleep = enabled;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('environmentKeyRequired'))),
      );
      return;
    }

    final updated = <String, String>{..._environmentSettings};
    if (replaceKey != null && replaceKey != normalizedKey) {
      updated.remove(replaceKey);
    }
    updated[normalizedKey] = normalizedValue;
    await Preferences.setEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _environmentSettings = updated;
    });
  }

  Future<void> _showEnvironmentSettingDialog({String? initialKey}) async {
    final initialValue =
        initialKey == null ? '' : _environmentSettings[initialKey] ?? '';
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
    if (!_environmentSettings.containsKey(key)) {
      return;
    }
    final updated = <String, String>{..._environmentSettings}..remove(key);
    await Preferences.setEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _environmentSettings = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmedOutputPath = _outputDirController.text.trim();
    final outputPathText = trimmedOutputPath.isEmpty
        ? l10n.tr('outputPathUnset')
        : trimmedOutputPath;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Text(
                      l10n.tr('generalSettingsTitle'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_outlined),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.tr('storagePathTitle'),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              outputPathText,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: widget.controlsEnabled
                                  ? _browseBasePath
                                  : null,
                              child: Text(l10n.tr('changePath')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.tr('ssePushSwitchTitle'),
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.tr('ssePushDescription'),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Switch.adaptive(
                                  value: _useSsePush,
                                  onChanged: widget.controlsEnabled
                                      ? _setSsePushEnabled
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l10n.tr('ssePushHint'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.tr('antiSleepTitle'),
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.tr('antiSleepDescription'),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Switch.adaptive(
                                  value: _useAntiSleep,
                                  onChanged: widget.controlsEnabled
                                      ? _setAntiSleepEnabled
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _useAntiSleep
                                        ? l10n.tr('antiSleepEnabledHint')
                                        : l10n.tr('antiSleepDisabledHint'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                     DecoratedBox(
                       decoration: BoxDecoration(
                         border: Border.all(color: colorScheme.outlineVariant),
                         borderRadius: BorderRadius.circular(18),
                       ),
                       child: Padding(
                         padding: const EdgeInsets.all(16),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Row(
                               children: [
                                 const Icon(Icons.code_outlined),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: Text(
                                     l10n.tr('environmentSettingsTitle'),
                                     style: theme.textTheme.titleMedium,
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 8),
                             Row(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Icon(
                                   Icons.warning_amber_rounded,
                                   size: 16,
                                   color: colorScheme.error,
                                 ),
                                 const SizedBox(width: 6),
                                 Expanded(
                                   child: Text(
                                     l10n.tr('environmentSettingsWarning'),
                                     style: theme.textTheme.bodySmall?.copyWith(
                                       color: colorScheme.error,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: widget.controlsEnabled
                                  ? () => _showEnvironmentSettingDialog()
                                  : null,
                              icon: const Icon(Icons.add),
                              label: Text(l10n.tr('addEnvironmentSetting')),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n.tr('savedEnvironmentSettingsTitle'),
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (_environmentSettings.isEmpty)
                              Text(
                                l10n.tr('environmentSettingsEmpty'),
                                style: theme.textTheme.bodySmall,
                              )
                            else
                              ..._environmentSettings.entries.map((entry) {
                                // 在這裡包上 Material
                                return Material(
                                  color: Colors.transparent, // 保持透明，露出底下的 DecoratedBox 顏色
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
                                      onPressed: widget.controlsEnabled
                                          ? () => _removeEnvironmentSetting(entry.key)
                                          : null,
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: l10n.tr('removeEnvironmentSetting'),
                                    ),
                                    onTap: widget.controlsEnabled
                                        ? () => _showEnvironmentSettingDialog(
                                        initialKey: entry.key)
                                        : null,
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentSettingInput {
  const _EnvironmentSettingInput({required this.key, required this.value});

  final String key;
  final String value;
}
