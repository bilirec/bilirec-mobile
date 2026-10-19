import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_sheet_toast.dart';
import 'package:bilirec/app/widgets/settings/settings_switch_row.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/external_storage_permission_prompt.dart';
import 'package:bilirec/shared/managed_environment_store.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/storage_protection_env.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class OutputPathSection extends StatefulWidget {
  const OutputPathSection({
    required this.enabled,
    required this.managedEnvironment,
    super.key,
  });

  final bool enabled;
  final ManagedEnvironmentStore managedEnvironment;

  @override
  State<OutputPathSection> createState() => _OutputPathSectionState();
}

class _OutputPathSectionState extends State<OutputPathSection> {
  final TextEditingController _outputDirController = TextEditingController();
  bool? _microSdProtectionEnabled;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outputPath = await Preferences.getOutputDir() ?? '';
    final managed = await Preferences.getManagedEnvironmentSettings();
    if (!mounted) return;
    _outputDirController.text = outputPath;
    setState(() {
      _microSdProtectionEnabled = isSequentialWriteEnabled(managed);
    });
  }

  @override
  void dispose() {
    _outputDirController.dispose();
    super.dispose();
  }

  Future<void> _browseBasePath() async {
    final granted = await ensureExternalStoragePermissionWithPrompt(
      context: context,
      dialogTitle: l10n.tr('outputPathPermissionDialogTitle'),
      dialogContent: l10n.tr('outputPathPermissionDialogContent'),
      confirmLabel: l10n.tr('outputPathPermissionDialogConfirm'),
      deniedToastMessage: '⚠️ ${l10n.tr('outputPathPermissionDenied')}',
      showToast: (message) => showSettingsToast(context, message),
    );
    if (!granted || !mounted) return;

    final currentDir = _outputDirController.text.trim();
    final initialDir = currentDir.isNotEmpty ? currentDir : null;

    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.tr('selectOutputPath'),
      initialDirectory: initialDir,
    );

    if (selected == null || !mounted) return;

    setState(() {
      _outputDirController.text = selected;
    });

    await Preferences.setOutputDir(selected);
  }

  Future<void> _restoreDefaultOutputPath() async {
    await Preferences.setOutputDir(null);
    if (!mounted) return;
    setState(() {
      _outputDirController.clear();
    });
  }

  Future<void> _setMicroSdProtectionEnabled(bool enabled) async {
    await widget.managedEnvironment.update((current) {
      return applyStorageProtectionEnv(
        env: current,
        protectionEnabled: enabled,
        maxConcurrent: parseMaxConcurrentRecordings(current),
      );
    });
    if (!mounted) return;
    setState(() {
      _microSdProtectionEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final microSd = _microSdProtectionEnabled;
    if (microSd == null) {
      return const SizedBox(height: 48);
    }

    final trimmedOutputPath = _outputDirController.text.trim();
    final hasCustomOutputPath = trimmedOutputPath.isNotEmpty;
    final outputPathText = trimmedOutputPath.isEmpty
        ? l10n.tr('outputPathUnset')
        : trimmedOutputPath;
    final theme = Theme.of(context);

    return SettingsSectionCard(
      icon: Icons.storage_outlined,
      title: l10n.tr('storagePolicyTitle'),
      description: l10n.tr('storagePolicyDescription'),
      children: [
        Text(
          l10n.tr('storagePathTitle'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          outputPathText,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: widget.enabled ? _browseBasePath : null,
              child: Text(l10n.tr('changePath')),
            ),
            OutlinedButton(
              onPressed: widget.enabled && hasCustomOutputPath
                  ? _restoreDefaultOutputPath
                  : null,
              child: Text(l10n.tr('restoreDefaultPath')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSwitchRow(
          title: l10n.tr('microSdWearProtectionTitle'),
          titleStyle: theme.textTheme.titleSmall,
          spacing: 6,
          description: l10n.tr('microSdWearProtectionDescription'),
          descriptionStyle: theme.textTheme.bodySmall,
          value: microSd,
          enabled: widget.enabled,
          onChanged: _setMicroSdProtectionEnabled,
        ),
      ],
    );
  }
}
