import 'dart:async';

import 'package:bilirec/app/widgets/github_proxy_custom_dialog.dart';
import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_sheet_toast.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/browser_launcher.dart';
import 'package:bilirec/shared/github_api_probe.dart';
import 'package:bilirec/shared/github_api_proxy_presets.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';

class GithubProxySection extends StatefulWidget {
  const GithubProxySection({required this.enabled, super.key});

  final bool enabled;

  @override
  State<GithubProxySection> createState() => _GithubProxySectionState();
}

class _GithubProxySectionState extends State<GithubProxySection> {
  String _githubApiProxyPreset = githubApiProxyPresetOfficial;
  GitHubProxySettings _githubProxySettings = const GitHubProxySettings(
    apiBaseUrl: '',
    githubBaseUrl: '',
  );
  int _githubApiPresetCheckGeneration = 0;
  bool _githubApiPresetChecking = false;
  String? _githubApiPresetFieldError;
  bool _githubApiPresetFieldOk = false;
  bool _loaded = false;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final githubProxy = await Preferences.getGitHubProxySettings();
    if (!mounted) return;
    _applyGitHubProxyToUi(githubProxy, scheduleCheck: true);
    setState(() {
      _loaded = true;
    });
  }

  void _applyGitHubProxyToUi(
    GitHubProxySettings stored, {
    bool scheduleCheck = false,
  }) {
    _githubProxySettings = stored;
    _githubApiProxyPreset = githubApiProxyPresetIdFromStored(
      apiBase: stored.apiBaseUrl,
      githubBase: stored.githubBaseUrl,
    );
    if (!scheduleCheck ||
        (stored.apiBaseUrl.isEmpty && stored.githubBaseUrl.isEmpty)) {
      return;
    }
    if (_githubApiProxyPreset != githubApiProxyPresetOfficial &&
        _githubApiProxyPreset != githubApiProxyPresetCustom) {
      _scheduleGitHubApiPresetCheck(_githubApiProxyPreset);
    }
  }

  void _resetGitHubApiPresetFieldState() {
    _githubApiPresetCheckGeneration++;
    _githubApiPresetChecking = false;
    _githubApiPresetFieldError = null;
    _githubApiPresetFieldOk = false;
  }

  void _scheduleGitHubApiPresetCheck(String presetId) {
    _githubApiPresetCheckGeneration++;
    if (mounted) {
      setState(_resetGitHubApiPresetFieldState);
    }

    final settings = githubProxySettingsForPresetId(presetId);
    if (settings.apiBaseUrl.isEmpty) {
      return;
    }

    final generation = _githubApiPresetCheckGeneration;
    unawaited(
      _runGitHubApiPresetCheck(
        settings: settings,
        generation: generation,
        presetId: presetId,
      ),
    );
  }

  Future<void> _saveGitHubProxyPreference(String preset) async {
    final settings = githubProxySettingsForPresetId(preset);
    await Preferences.setGitHubProxySettings(settings);
    if (mounted) {
      setState(() => _githubProxySettings = settings);
    }
  }

  Future<void> _openGitHubProxyCustomDialog() async {
    final storedPreset = githubApiProxyPresetIdFromStored(
      apiBase: _githubProxySettings.apiBaseUrl,
      githubBase: _githubProxySettings.githubBaseUrl,
    );
    final initial = storedPreset == githubApiProxyPresetCustom
        ? _githubProxySettings
        : const GitHubProxySettings(
            apiBaseUrl: '',
            githubBaseUrl: '',
          );
    final saved = await showGitHubProxyCustomDialog(
      context,
      initial: initial,
      docsUrl: _githubApiProxyDocsUrl(),
    );
    if (!mounted || saved == null) {
      return;
    }
    await Preferences.setGitHubProxySettings(saved);
    if (!mounted) {
      return;
    }
    setState(() {
      _githubProxySettings = saved;
      _githubApiProxyPreset = githubApiProxyPresetCustom;
      _resetGitHubApiPresetFieldState();
    });
    showSettingsToast(
      context,
      '✅ ${l10n.tr('githubApiProxyCustomSaveSuccess')}',
      location: AppToastLocation.bottom,
    );
  }

  Future<void> _onGitHubApiProxyPresetChanged(String value) async {
    if (value == githubApiProxyPresetCustom) {
      setState(() {
        _githubApiProxyPreset = githubApiProxyPresetCustom;
        _resetGitHubApiPresetFieldState();
      });
      return;
    }

    setState(() => _githubApiProxyPreset = value);
    if (value == githubApiProxyPresetOfficial) {
      if (mounted) {
        setState(_resetGitHubApiPresetFieldState);
      }
      await _saveGitHubProxyPreference(value);
      return;
    }
    if (mounted) {
      setState(_resetGitHubApiPresetFieldState);
    }
    _scheduleGitHubApiPresetCheck(value);
  }

  Future<void> _runGitHubApiPresetCheck({
    required GitHubProxySettings settings,
    required int generation,
    required String presetId,
  }) async {
    if (!mounted || generation != _githubApiPresetCheckGeneration) {
      return;
    }
    setState(() {
      _githubApiPresetChecking = true;
      _githubApiPresetFieldError = null;
      _githubApiPresetFieldOk = false;
    });

    final reachable = await probeGitHubApiBase(apiBase: settings.apiBaseUrl);
    if (!mounted || generation != _githubApiPresetCheckGeneration) {
      return;
    }

    if (_githubApiProxyPreset != presetId) {
      setState(() => _githubApiPresetChecking = false);
      return;
    }

    if (reachable) {
      await Preferences.setGitHubProxySettings(settings);
      if (mounted) {
        setState(() => _githubProxySettings = settings);
      }
    }

    setState(() {
      _githubApiPresetChecking = false;
      if (reachable) {
        _githubApiPresetFieldError = null;
        _githubApiPresetFieldOk = true;
      } else {
        _githubApiPresetFieldError = l10n.tr('githubApiProxyCustomUnreachable');
        _githubApiPresetFieldOk = false;
      }
    });
  }

  String? _githubApiProxyDropdownError() {
    if (_githubApiProxyPreset == githubApiProxyPresetOfficial ||
        _githubApiProxyPreset == githubApiProxyPresetCustom) {
      return null;
    }
    return _githubApiPresetFieldError;
  }

  String? _githubApiProxyDropdownHelper() {
    if (_githubApiProxyPreset == githubApiProxyPresetOfficial ||
        _githubApiProxyPreset == githubApiProxyPresetCustom) {
      return null;
    }
    if (_githubApiPresetChecking) {
      return l10n.tr('githubApiProxyCustomChecking');
    }
    if (_githubApiPresetFieldOk && _githubApiPresetFieldError == null) {
      return l10n.tr('githubApiProxyCustomReachable');
    }
    return null;
  }

  String _githubApiProxyDocsUrl() {
    final languageCode = AppLocaleConfig.codeForLocale(l10n.locale);
    final localeSegment =
        languageCode == AppLocaleConfig.simplifiedCode ? 'zh-cn' : 'zh-tw';
    final anchor = languageCode == AppLocaleConfig.simplifiedCode
        ? '无法直连-github-时github_api_url'
        : '無法直連-github-時github_api_url';
    return 'https://www.bilirec.org/$localeSegment/api/version/#$anchor';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(height: 48);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SettingsSectionCard(
      icon: Icons.system_update_alt_outlined,
      title: l10n.tr('updatePolicyTitle'),
      description: l10n.tr('updatePolicyDescription'),
      children: [
        Text(
          l10n.tr('githubApiProxyTitle'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _githubApiProxyPreset,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            errorText: _githubApiProxyDropdownError(),
            errorMaxLines: 3,
            helperText: _githubApiProxyDropdownHelper(),
            helperMaxLines: 3,
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: _githubApiPresetChecking
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.primary,
            ),
            suffixIcon: _githubApiPresetChecking &&
                    _githubApiProxyPreset != githubApiProxyPresetOfficial &&
                    _githubApiProxyPreset != githubApiProxyPresetCustom
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
          items: [
            DropdownMenuItem(
              value: githubApiProxyPresetOfficial,
              child: Text(
                l10n.tr('githubApiProxyOptionOfficial'),
              ),
            ),
            ...kGitHubApiProxyPresets.map(
              (preset) => DropdownMenuItem(
                value: preset.id,
                child: Text(preset.label),
              ),
            ),
            DropdownMenuItem(
              value: githubApiProxyPresetCustom,
              child: Text(
                l10n.tr('githubApiProxyOptionCustom'),
              ),
            ),
          ],
          onChanged: widget.enabled
              ? (value) async {
                  if (value == null) return;
                  await _onGitHubApiProxyPresetChanged(value);
                }
              : null,
        ),
        if (_githubApiProxyPreset == githubApiProxyPresetCustom) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.enabled ? _openGitHubProxyCustomDialog : null,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.tr('githubApiProxyCustomEdit')),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SettingsHint(
          text: l10n.tr('githubApiProxyHint'),
          inlineLinkLabel: l10n.tr('githubApiProxyHintLink'),
          onInlineLinkTap: () {
            launchUrlInSystemBrowser(
              Uri.parse(_githubApiProxyDocsUrl()),
            );
          },
        ),
      ],
    );
  }
}
