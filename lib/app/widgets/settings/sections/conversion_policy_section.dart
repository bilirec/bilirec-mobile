import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/app/widgets/settings/settings_range_slider.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_switch_tile.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/managed_environment_store.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';

class ConversionPolicySection extends StatefulWidget {
  const ConversionPolicySection({
    required this.enabled,
    required this.managedEnvironment,
    super.key,
  });

  final bool enabled;
  final ManagedEnvironmentStore managedEnvironment;

  @override
  State<ConversionPolicySection> createState() =>
      _ConversionPolicySectionState();
}

class _ConversionPolicySectionState extends State<ConversionPolicySection> {
  bool? _convertToMp4;
  bool? _deleteSourceAfterConvert;
  bool? _ffmpegAllowDuringRecording;
  int? _ffmpegAllowDuringRecordingMaxActive;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await Preferences.getManagedEnvironmentSettings();
    if (!mounted) return;
    setState(() {
      _convertToMp4 = _readBoolFromEnv(settings, 'CONVERT_TO_MP4');
      _deleteSourceAfterConvert =
          _readBoolFromEnv(settings, 'DELETE_SOURCE_AFTER_CONVERT');
      _ffmpegAllowDuringRecording =
          _readBoolFromEnv(settings, 'FFMPEG_ALLOW_DURING_RECORDING');
      _ffmpegAllowDuringRecordingMaxActive = _readBoundedIntFromEnv(
        settings,
        'FFMPEG_ALLOW_DURING_RECORDING_MAX_ACTIVE_RECORDINGS',
        fallback: 1,
        min: 0,
        max: 5,
      );
    });
  }

  bool _readBoolFromEnv(Map<String, String> env, String key) {
    final raw = (env[key] ?? '').trim().toLowerCase();
    return raw == 'true';
  }

  int _readBoundedIntFromEnv(
    Map<String, String> env,
    String key, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final parsed = int.tryParse(env[key] ?? '');
    if (parsed == null) return fallback;
    return parsed.clamp(min, max);
  }

  Future<void> _setConvertToMp4Enabled(bool enabled) async {
    await widget.managedEnvironment.update((current) {
      current['CONVERT_TO_MP4'] = '$enabled';
      if (!enabled) {
        current['DELETE_SOURCE_AFTER_CONVERT'] = 'false';
      }
      return current;
    });
    if (!mounted) return;
    setState(() {
      _convertToMp4 = enabled;
      if (!enabled) {
        _deleteSourceAfterConvert = false;
      }
    });
  }

  Future<void> _setDeleteSourceAfterConvertEnabled(bool enabled) async {
    await widget.managedEnvironment.update((current) {
      current['DELETE_SOURCE_AFTER_CONVERT'] = '$enabled';
      return current;
    });
    if (!mounted) return;
    setState(() {
      _deleteSourceAfterConvert = enabled;
    });
  }

  Future<void> _setFfmpegAllowDuringRecordingEnabled(bool enabled) async {
    await widget.managedEnvironment.update((current) {
      current['FFMPEG_ALLOW_DURING_RECORDING'] = '$enabled';
      if (!enabled) {
        current['FFMPEG_ALLOW_DURING_RECORDING_MAX_ACTIVE_RECORDINGS'] = '1';
      }
      return current;
    });
    if (!mounted) return;
    setState(() {
      _ffmpegAllowDuringRecording = enabled;
      if (!enabled) {
        _ffmpegAllowDuringRecordingMaxActive = 1;
      }
    });
  }

  Future<void> _setFfmpegAllowDuringRecordingMaxActive(int value) async {
    final bounded = value.clamp(0, 5);
    await widget.managedEnvironment.set(
      'FFMPEG_ALLOW_DURING_RECORDING_MAX_ACTIVE_RECORDINGS',
      '$bounded',
    );
    if (!mounted) return;
    setState(() {
      _ffmpegAllowDuringRecordingMaxActive = bounded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final convert = _convertToMp4;
    final deleteSource = _deleteSourceAfterConvert;
    final ffmpegAllow = _ffmpegAllowDuringRecording;
    final ffmpegMax = _ffmpegAllowDuringRecordingMaxActive;
    if (convert == null ||
        deleteSource == null ||
        ffmpegAllow == null ||
        ffmpegMax == null) {
      return const SizedBox(height: 48);
    }

    final theme = Theme.of(context);
    final ffmpegControlsEnabled = widget.enabled && convert;
    final ffmpegLimitEnabled = ffmpegControlsEnabled && ffmpegAllow;

    return SettingsSectionCard(
      icon: Icons.transform_rounded,
      title: l10n.tr('conversionPolicyTitle'),
      description: l10n.tr('conversionPolicyDescription'),
      children: [
        Text(
          l10n.tr('fileConversionTitle'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.tr('convertToMp4Description'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SettingsSwitchTile(
          title: l10n.tr('convertToMp4Title'),
          subtitle: l10n.tr('convertToMp4SecondaryDescription'),
          value: convert,
          enabled: widget.enabled,
          onChanged: _setConvertToMp4Enabled,
        ),
        SettingsSwitchTile(
          title: l10n.tr('deleteSourceAfterConvertTitle'),
          subtitle: l10n.tr('deleteSourceAfterConvertDescription'),
          value: deleteSource,
          enabled: widget.enabled && convert,
          onChanged: _setDeleteSourceAfterConvertEnabled,
        ),
        const SizedBox(height: 14),
        SettingsSwitchTile(
          title: l10n.tr('ffmpegAllowDuringRecordingTitle'),
          subtitle: l10n.tr('ffmpegAllowDuringRecordingDescription'),
          value: ffmpegAllow,
          enabled: ffmpegControlsEnabled,
          onChanged: _setFfmpegAllowDuringRecordingEnabled,
        ),
        if (ffmpegAllow)
          SettingsHint(
            tone: SettingsHintTone.warning,
            text: l10n.tr('ffmpegAllowDuringRecordingWarning'),
          ),
        const SizedBox(height: 8),
        SettingsRangeSlider(
          title: l10n.tr('ffmpegMaxActiveRecordingsTitle'),
          description: l10n.tr('ffmpegMaxActiveRecordingsDescription'),
          value: ffmpegMax,
          min: 0,
          max: 5,
          divisions: 5,
          valueLabel: ffmpegMax == 0
              ? l10n.tr('ffmpegMaxActiveUnlimitedOption')
              : l10n.tr(
                  'ffmpegMaxActiveOption',
                  params: {'value': '$ffmpegMax'},
                ),
          enabled: ffmpegLimitEnabled,
          dimmedWhenDisabled: true,
          onChanged: (value) {
            setState(() {
              _ffmpegAllowDuringRecordingMaxActive = value;
            });
          },
          onChangeEnd: (value) {
            _setFfmpegAllowDuringRecordingMaxActive(value);
          },
        ),
      ],
    );
  }
}
