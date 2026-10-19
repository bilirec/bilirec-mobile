import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_switch_row.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';

class GeneralTogglesSection extends StatefulWidget {
  const GeneralTogglesSection({required this.enabled, super.key});

  final bool enabled;

  @override
  State<GeneralTogglesSection> createState() => _GeneralTogglesSectionState();
}

class _GeneralTogglesSectionState extends State<GeneralTogglesSection> {
  bool? _useSsePush;
  bool? _useAntiSleep;
  bool? _useAutoRunOnBoot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sse = await Preferences.getEnableSsePush();
    final antiSleep = await Preferences.getEnableAntiSleep();
    final autoRun = await Preferences.getEnableAutoRunOnBoot();
    if (!mounted) return;
    setState(() {
      _useSsePush = sse;
      _useAntiSleep = antiSleep;
      _useAutoRunOnBoot = autoRun;
    });
  }

  Future<void> _setSse(bool value) async {
    await Preferences.setEnableSsePush(value);
    if (!mounted) return;
    setState(() => _useSsePush = value);
  }

  Future<void> _setAntiSleep(bool value) async {
    await Preferences.setEnableAntiSleep(value);
    if (!mounted) return;
    setState(() => _useAntiSleep = value);
  }

  Future<void> _setAutoRun(bool value) async {
    await Preferences.setEnableAutoRunOnBoot(value);
    if (!mounted) return;
    setState(() => _useAutoRunOnBoot = value);
  }

  @override
  Widget build(BuildContext context) {
    final sse = _useSsePush;
    final antiSleep = _useAntiSleep;
    final autoRun = _useAutoRunOnBoot;
    if (sse == null || antiSleep == null || autoRun == null) {
      return const SizedBox(height: 48);
    }

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionCard(
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
          ],
        ),
        const SizedBox(height: 20),
        SettingsSectionCard(
          children: [
            SettingsSwitchRow(
              title: l10n.tr('antiSleepTitle'),
              description: l10n.tr('antiSleepDescription'),
              value: antiSleep,
              enabled: widget.enabled,
              onChanged: _setAntiSleep,
            ),
            const SizedBox(height: 12),
            SettingsHint(
              text: antiSleep
                  ? l10n.tr('antiSleepEnabledHint')
                  : l10n.tr('antiSleepDisabledHint'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsSectionCard(
          children: [
            SettingsSwitchRow(
              title: l10n.tr('autoRunOnBootTitle'),
              description: l10n.tr('autoRunOnBootDescription'),
              value: autoRun,
              enabled: widget.enabled,
              onChanged: _setAutoRun,
            ),
            const SizedBox(height: 12),
            SettingsHint(
              text: l10n.tr('autoRunOnBootHint'),
            ),
          ],
        ),
      ],
    );
  }
}
