import 'package:bilirec/app/widgets/settings/sections/bootstrap_log_section.dart';
import 'package:bilirec/app/widgets/settings/sections/conversion_policy_section.dart';
import 'package:bilirec/app/widgets/settings/sections/danmaku_policy_section.dart';
import 'package:bilirec/app/widgets/settings/sections/develop_environment_section.dart';
import 'package:bilirec/app/widgets/settings/sections/external_browser_section.dart';
import 'package:bilirec/app/widgets/settings/sections/general_toggles_section.dart';
import 'package:bilirec/app/widgets/settings/sections/github_proxy_section.dart';
import 'package:bilirec/app/widgets/settings/sections/output_path_section.dart';
import 'package:bilirec/app/widgets/settings/sections/recording_policy_section.dart';
import 'package:bilirec/app/widgets/settings/sections/subcheck_policy_section.dart';
import 'package:bilirec/app/widgets/settings/sections/subscription_maintenance_section.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/managed_environment_store.dart';
import 'package:flutter/material.dart';

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
  final ManagedEnvironmentStore _managedEnvironment = ManagedEnvironmentStore();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = widget.controlsEnabled;
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Center(child: _SheetHandle()),
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
                  GeneralTogglesSection(enabled: enabled),
                  const SizedBox(height: 20),
                  ExternalBrowserSection(enabled: enabled),
                  const SizedBox(height: 20),
                  OutputPathSection(
                    enabled: enabled,
                    managedEnvironment: _managedEnvironment,
                  ),
                  const SizedBox(height: 20),
                  RecordingPolicySection(
                    enabled: enabled,
                    managedEnvironment: _managedEnvironment,
                  ),
                  const SizedBox(height: 20),
                  SubcheckPolicySection(
                    enabled: enabled,
                    managedEnvironment: _managedEnvironment,
                  ),
                  const SizedBox(height: 20),
                  DanmakuPolicySection(
                    enabled: enabled,
                    managedEnvironment: _managedEnvironment,
                  ),
                  const SizedBox(height: 20),
                  ConversionPolicySection(
                    enabled: enabled,
                    managedEnvironment: _managedEnvironment,
                  ),
                  const SizedBox(height: 20),
                  GithubProxySection(enabled: enabled),
                  const SizedBox(height: 20),
                  DevelopEnvironmentSection(enabled: enabled),
                  const SizedBox(height: 12),
                  const BootstrapLogSection(),
                  const SizedBox(height: 12),
                  const SubscriptionMaintenanceSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
