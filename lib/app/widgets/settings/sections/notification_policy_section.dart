import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_switch_row.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';

class NotificationPolicySection extends StatefulWidget {
  const NotificationPolicySection({required this.enabled, super.key});

  final bool enabled;

  @override
  State<NotificationPolicySection> createState() =>
      _NotificationPolicySectionState();
}

class _NotificationPolicySectionState extends State<NotificationPolicySection> {
  bool? _useSsePush;
  bool? _useMetricsAlerts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sse = await Preferences.getEnableSsePush();
    final metricsAlerts = await Preferences.getEnableMetricsAlerts();
    if (!mounted) return;
    setState(() {
      _useSsePush = sse;
      _useMetricsAlerts = metricsAlerts;
    });
  }

  Future<void> _setSse(bool value) async {
    await Preferences.setEnableSsePush(value);
    if (!mounted) return;
    setState(() => _useSsePush = value);
  }

  Future<void> _setMetricsAlerts(bool value) async {
    await Preferences.setEnableMetricsAlerts(value);
    if (!mounted) return;
    setState(() => _useMetricsAlerts = value);
  }

  @override
  Widget build(BuildContext context) {
    final sse = _useSsePush;
    final metricsAlerts = _useMetricsAlerts;
    if (sse == null || metricsAlerts == null) {
      return const SizedBox(height: 48);
    }

    final l10n = AppLocalizations.of(context);
    return SettingsSectionCard(
      icon: Icons.notifications_active_outlined,
      title: l10n.tr('notificationPolicyTitle'),
      description: l10n.tr('notificationPolicyDescription'),
      children: [
        SettingsSwitchRow(
          title: l10n.tr('ssePushSwitchTitle'),
          description: l10n.tr('ssePushDescription'),
          value: sse,
          enabled: widget.enabled,
          onChanged: _setSse,
        ),
        const SizedBox(height: 12),
        SettingsHint(
          text: l10n.tr('ssePushHint'),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        SettingsSwitchRow(
          title: l10n.tr('metricsAlertsSwitchTitle'),
          description: l10n.tr('metricsAlertsDescription'),
          value: metricsAlerts,
          enabled: widget.enabled,
          onChanged: _setMetricsAlerts,
        ),
      ],
    );
  }
}
