import 'package:bilirec/app/widgets/external_browser_picker_sheet.dart';
import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/browser_launcher.dart';
import 'package:bilirec/shared/browser_packages.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ExternalBrowserSection extends StatefulWidget {
  const ExternalBrowserSection({required this.enabled, super.key});

  final bool enabled;

  @override
  State<ExternalBrowserSection> createState() => _ExternalBrowserSectionState();
}

class _ExternalBrowserSectionState extends State<ExternalBrowserSection> {
  String? _externalBrowserChoice;
  List<HttpsBrowserInfo> _installedHttpsBrowsers = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final choice = await Preferences.getExternalBrowserChoice();
    List<HttpsBrowserInfo> installedBrowsers = const [];
    try {
      installedBrowsers = await listHttpsBrowsers();
    } catch (_) {
      installedBrowsers = const [];
    }
    if (!mounted) return;
    setState(() {
      _externalBrowserChoice = choice;
      _installedHttpsBrowsers = installedBrowsers;
      _loaded = true;
    });
  }

  Future<void> _changeExternalBrowser() async {
    final picked = await showExternalBrowserPickerSheet(
      context,
      currentChoice: _externalBrowserChoice,
    );
    if (picked == null || !mounted) {
      return;
    }
    await Preferences.setExternalBrowserChoice(picked.choice);
    final installedBrowsers = await listHttpsBrowsers();
    if (!mounted) {
      return;
    }
    setState(() {
      _externalBrowserChoice = picked.choice;
      _installedHttpsBrowsers = installedBrowsers;
    });
  }

  Future<void> _clearExternalBrowserPreference() async {
    await Preferences.clearExternalBrowserChoice();
    if (!mounted) {
      return;
    }
    setState(() => _externalBrowserChoice = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(height: 48);
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SettingsSectionCard(
      title: l10n.tr('externalBrowserSettingsTitle'),
      children: [
        SettingsHint(
          text: l10n.tr('externalBrowserSettingsDescription'),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.tr('externalBrowserCurrentLabel'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          externalBrowserDisplayLabel(
            l10n: l10n,
            storedChoice: _externalBrowserChoice,
            installedBrowsers: _installedHttpsBrowsers,
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: widget.enabled ? _changeExternalBrowser : null,
          child: Text(l10n.tr('externalBrowserChangeButton')),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.enabled && _externalBrowserChoice != null
                ? _clearExternalBrowserPreference
                : null,
            child: Text(
              l10n.tr('externalBrowserClearPreferenceDebug'),
            ),
          ),
        ],
      ],
    );
  }
}
