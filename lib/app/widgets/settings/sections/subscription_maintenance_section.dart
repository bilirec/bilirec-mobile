import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_sheet_toast.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/subscription_list_transfer.dart';
import 'package:flutter/material.dart';

class SubscriptionMaintenanceSection extends StatefulWidget {
  const SubscriptionMaintenanceSection({super.key});

  @override
  State<SubscriptionMaintenanceSection> createState() =>
      _SubscriptionMaintenanceSectionState();
}

class _SubscriptionMaintenanceSectionState
    extends State<SubscriptionMaintenanceSection> {
  final SubscriptionListTransfer _transfer = SubscriptionListTransfer();
  bool _exportingSubscriptionList = false;
  bool _importingSubscriptionList = false;
  bool _resettingSubscriptionList = false;

  AppLocalizations get l10n => AppLocalizations.of(context);

  bool get _busy =>
      _exportingSubscriptionList ||
      _importingSubscriptionList ||
      _resettingSubscriptionList;

  Future<void> _exportSubscriptionList() async {
    if (_busy) return;
    setState(() {
      _exportingSubscriptionList = true;
    });

    try {
      final result = await _transfer.export(
        dialogTitle: l10n.tr('selectSubscriptionListExportPath'),
      );
      if (!mounted) return;
      switch (result) {
        case SubscriptionListCancelled():
          return;
        case SubscriptionListNotFound():
          showSettingsToast(
            context,
            '⚠️ ${l10n.tr('subscriptionListNotFound')}',
            location: AppToastLocation.bottom,
          );
        case SubscriptionListNotWritable():
          showSettingsToast(
            context,
            '⚠️ ${l10n.tr('externalStoragePermissionDenied')}',
            location: AppToastLocation.bottom,
          );
        case SubscriptionListFailed(:final error):
          showSettingsToast(
            context,
            l10n.tr('exportSubscriptionListFailed', params: {'error': '$error'}),
            location: AppToastLocation.bottom,
          );
        case SubscriptionListSucceeded(:final path):
          showSettingsToast(
            context,
            l10n.tr('exportSubscriptionListSuccess', params: {'path': path}),
            location: AppToastLocation.bottom,
          );
        case SubscriptionListInvalidFile():
        case SubscriptionListSamePath():
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingSubscriptionList = false;
        });
      }
    }
  }

  Future<void> _importSubscriptionList() async {
    if (_busy) return;

    final confirmed = await _showWarningConfirmDialog(
      title: l10n.tr('importSubscriptionRiskTitle'),
      description: l10n.tr('importSubscriptionRiskDescription'),
      confirmLabel: l10n.tr('importSubscriptionRiskConfirm'),
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _importingSubscriptionList = true;
    });

    try {
      final picked = await SubscriptionListPicker.pick(
        dialogTitle: l10n.tr('selectSubscriptionListImportFile'),
      );
      if (picked == null) {
        return;
      }

      final result = await _transfer.importPickedFile(
        sourcePath: picked.path,
        bytes: picked.bytes,
        sourceName: picked.name,
      );
      if (!mounted) return;
      switch (result) {
        case SubscriptionListInvalidFile():
          showSettingsToast(
            context,
            '⚠️ ${l10n.tr('importSubscriptionListInvalidFile')}',
            location: AppToastLocation.bottom,
          );
        case SubscriptionListSamePath():
          showSettingsToast(
            context,
            '⚠️ ${l10n.tr('importSubscriptionListSamePath')}',
            location: AppToastLocation.bottom,
          );
        case SubscriptionListFailed(:final error):
          showSettingsToast(
            context,
            l10n.tr('importSubscriptionListFailed', params: {'error': '$error'}),
            location: AppToastLocation.bottom,
          );
        case SubscriptionListSucceeded(:final path):
          showSettingsToast(
            context,
            l10n.tr('importSubscriptionListSuccess', params: {'path': path}),
            location: AppToastLocation.bottom,
          );
        case SubscriptionListNotFound():
        case SubscriptionListCancelled():
        case SubscriptionListNotWritable():
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _importingSubscriptionList = false;
        });
      }
    }
  }

  Future<void> _resetSubscriptionList() async {
    if (_busy) return;

    final confirmed = await _showWarningConfirmDialog(
      title: l10n.tr('resetSubscriptionListWarningTitle'),
      description: l10n.tr('resetSubscriptionListWarningDescription'),
      confirmLabel: l10n.tr('resetSubscriptionListWarningConfirm'),
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _resettingSubscriptionList = true;
    });

    try {
      final result = await _transfer.reset();
      if (!mounted) return;
      switch (result) {
        case SubscriptionListFailed(:final error):
          showSettingsToast(
            context,
            l10n.tr('resetSubscriptionListFailed', params: {'error': '$error'}),
            location: AppToastLocation.bottom,
          );
        case SubscriptionListSucceeded(:final path):
          showSettingsToast(
            context,
            l10n.tr('resetSubscriptionListSuccess', params: {'path': path}),
            location: AppToastLocation.bottom,
          );
        default:
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _resettingSubscriptionList = false;
        });
      }
    }
  }

  Future<bool> _showWarningConfirmDialog({
    required String title,
    required String description,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final textTheme = Theme.of(dialogContext).textTheme;

        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 30,
          ),
          title: Text(title),
          content: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.error),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.onErrorContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.warning_rounded),
              label: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSectionCard(
      icon: Icons.playlist_add_check_outlined,
      title: l10n.tr('subscriptionListTransferTitle'),
      description: l10n.tr('subscriptionListTransferDescription'),
      descriptionStyle: theme.textTheme.bodyMedium,
      headerSpacing: 12,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _exportSubscriptionList,
              icon: _exportingSubscriptionList
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                l10n.tr('exportSubscriptionList'),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _importSubscriptionList,
              icon: _importingSubscriptionList
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(
                l10n.tr('importSubscriptionList'),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _resetSubscriptionList,
              icon: _resettingSubscriptionList
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.restart_alt_rounded),
              label: Text(
                l10n.tr('resetSubscriptionList'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
