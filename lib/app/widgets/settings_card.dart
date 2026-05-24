import 'package:bilirec/l10n/app_localizations.dart';
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
    required this.outputPath,
    required this.useSsePush,
    required this.controlsEnabled,
    required this.onBrowse,
    required this.onSsePushChanged,
    required this.onClose,
    super.key,
  });

  final String outputPath;
  final bool useSsePush;
  final bool controlsEnabled;
  final Future<String?> Function() onBrowse;
  final Future<void> Function(bool) onSsePushChanged;
  final VoidCallback onClose;

  @override
  State<SettingsDrawerSheet> createState() => _SettingsDrawerSheetState();
}

class _SettingsDrawerSheetState extends State<SettingsDrawerSheet> {
  late String _outputPath;
  late bool _useSsePush;

  @override
  void initState() {
    super.initState();
    _outputPath = widget.outputPath;
    _useSsePush = widget.useSsePush;
  }

  @override
  void didUpdateWidget(covariant SettingsDrawerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outputPath != widget.outputPath) {
      _outputPath = widget.outputPath;
    }
    if (oldWidget.useSsePush != widget.useSsePush) {
      _useSsePush = widget.useSsePush;
    }
  }

  Future<void> _handleBrowse() async {
    final selected = await widget.onBrowse();
    if (!mounted || selected == null) return;
    setState(() {
      _outputPath = selected;
    });
  }

  Future<void> _handleSsePushChanged(bool value) async {
    setState(() {
      _useSsePush = value;
    });
    await widget.onSsePushChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trimmedOutputPath = _outputPath.trim();
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
                    l10n.tr('setOutputPathTitle'),
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
                                widget.controlsEnabled ? _handleBrowse : null,
                            child: Text(l10n.tr('changePath')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.tr('notificationModeTitle'),
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
                                    ? _handleSsePushChanged
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
                                  _useSsePush
                                      ? l10n.tr('ssePushEnabledHint')
                                      : l10n.tr('ssePushDisabledHint'),
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
