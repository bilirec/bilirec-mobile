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
    required this.controlsEnabled,
    required this.onClose,
    super.key,
  });

  final bool controlsEnabled;
  final VoidCallback onClose;

  @override
  State<SettingsDrawerSheet> createState() => _SettingsDrawerSheetState();
}

class _SettingsDrawerSheetState extends State<SettingsDrawerSheet> {
  bool _useSsePush = false;
  bool _useAntiSleep = false;

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
    if (!mounted) return;
    _outputDirController.text = outputPath;
    setState(() {
      _useSsePush = useSsePush;
      _useAntiSleep = useAntiSleep;
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.tr('serviceStartupSettingsTitle'),
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
                            onPressed:
                                widget.controlsEnabled ? _browseBasePath : null,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  l10n.tr('antiSleepHint'),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
