import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_sheet_toast.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/bootstrap_log_exporter.dart';
import 'package:flutter/material.dart';

class BootstrapLogSection extends StatefulWidget {
  const BootstrapLogSection({super.key});

  @override
  State<BootstrapLogSection> createState() => _BootstrapLogSectionState();
}

class _BootstrapLogSectionState extends State<BootstrapLogSection> {
  final BootstrapLogExporter _exporter = BootstrapLogExporter();
  bool _downloadingBootstrapLog = false;

  AppLocalizations get l10n => AppLocalizations.of(context);

  Future<void> _downloadBootstrapLog() async {
    if (_downloadingBootstrapLog) return;
    setState(() {
      _downloadingBootstrapLog = true;
    });

    try {
      final result = await _exporter.export(
        dialogTitle: l10n.tr('selectLogDownloadPath'),
      );
      if (!mounted) return;
      switch (result) {
        case BootstrapLogCancelled():
          return;
        case BootstrapLogNotFound():
          showSettingsToast(
            context,
            '⚠️ ${l10n.tr('downloadBootstrapLogNotFound')}',
            location: AppToastLocation.bottom,
          );
        case BootstrapLogNotWritable():
          showSettingsToast(
            context,
            '⚠️ ${l10n.tr('externalStoragePermissionDenied')}',
            location: AppToastLocation.bottom,
          );
        case BootstrapLogFailed(:final error):
          showSettingsToast(
            context,
            l10n.tr(
              'downloadBootstrapLogFailed',
              params: {'error': '$error'},
            ),
            location: AppToastLocation.bottom,
          );
        case BootstrapLogExported(:final path, :final fileCount):
          showSettingsToast(
            context,
            l10n.tr(
              'downloadBootstrapLogSuccess',
              params: {
                'path': path,
                'count': '$fileCount',
              },
            ),
            location: AppToastLocation.bottom,
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingBootstrapLog = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSectionCard(
      icon: Icons.description_outlined,
      title: l10n.tr('bootstrapLogTitle'),
      description: l10n.tr('bootstrapLogDescription'),
      descriptionStyle: theme.textTheme.bodyMedium,
      headerSpacing: 12,
      children: [
        FilledButton.tonalIcon(
          onPressed: _downloadingBootstrapLog ? null : _downloadBootstrapLog,
          icon: _downloadingBootstrapLog
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.download_rounded),
          label: Text(
            _downloadingBootstrapLog
                ? l10n.tr('downloadingLog')
                : l10n.tr('downloadBootstrapLog'),
          ),
        ),
      ],
    );
  }
}
