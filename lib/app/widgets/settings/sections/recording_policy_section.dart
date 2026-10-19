import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/app/widgets/settings/settings_option_slider.dart';
import 'package:bilirec/app/widgets/settings/settings_range_slider.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_segmented_field.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/managed_environment_store.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/storage_protection_env.dart';
import 'package:flutter/material.dart';

class RecordingPolicySection extends StatefulWidget {
  const RecordingPolicySection({
    required this.enabled,
    required this.managedEnvironment,
    super.key,
  });

  final bool enabled;
  final ManagedEnvironmentStore managedEnvironment;

  @override
  State<RecordingPolicySection> createState() => _RecordingPolicySectionState();
}

class _RecordingPolicySectionState extends State<RecordingPolicySection> {
  static const int _bytesPerGb = 1024 * 1024 * 1024;
  static const List<int> _diskSpaceOptionsGb = <int>[0, 2, 5, 10];
  static const List<int> _retryMinuteOptions = <int>[
    0,
    5,
    10,
    15,
    20,
    25,
    30,
  ];
  static const List<int> _streamIdleTimeoutOptions = <int>[
    0,
    10,
    15,
    20,
    30,
    45,
    60,
  ];
  static const int _minMaxConcurrentRecordings = 3;
  static const int _maxMaxConcurrentRecordings = 15;
  static final List<int> _maxConcurrentRecordingOptions = List<int>.generate(
    _maxMaxConcurrentRecordings - _minMaxConcurrentRecordings + 1,
    (index) => _minMaxConcurrentRecordings + index,
  );

  static const int _defaultMaxRecordingHours = 5;
  static const int _defaultMinDiskSpaceGb = 5;
  static const int _defaultMaxRetryMinutes = 10;
  static const int _defaultStreamIdleTimeoutSecs = 20;
  static const int _defaultMaxConcurrentRecordings =
      _minMaxConcurrentRecordings;

  int? _maxRecordingHours;
  int? _minDiskSpaceGb;
  int? _maxRetryMinutes;
  int? _streamIdleTimeoutSecs;
  int? _maxConcurrentRecordings;
  String? _recordingRecoveryDuration;

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
      _maxRecordingHours = _readMaxRecordingHours(settings);
      _minDiskSpaceGb = _readMinDiskSpaceGb(settings);
      _maxRetryMinutes = _readMaxRetryMinutes(settings);
      _streamIdleTimeoutSecs = _readStreamIdleTimeoutSecs(settings);
      _recordingRecoveryDuration = _readRecordingRecoveryDuration(settings);
      _maxConcurrentRecordings = _readMaxConcurrentRecordings(settings);
    });
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

  int _readMaxRecordingHours(Map<String, String> env) {
    return _readBoundedIntFromEnv(
      env,
      'MAX_RECORDING_HOURS',
      fallback: _defaultMaxRecordingHours,
      min: 0,
      max: 12,
    );
  }

  int _readMaxRetryMinutes(Map<String, String> env) {
    final fallback = _defaultMaxRetryMinutes;
    final parsed = int.tryParse(env['MAX_RETRY_MINUTES'] ?? '');
    if (parsed == null) return fallback;

    final stepped = ((parsed / 5).round() * 5).clamp(0, 30);
    if (_retryMinuteOptions.contains(stepped)) {
      return stepped;
    }
    return fallback;
  }

  int _readStreamIdleTimeoutSecs(Map<String, String> env) {
    final parsed = int.tryParse(env['STREAM_IDLE_TIMEOUT'] ?? '');
    if (parsed == null) {
      return _defaultStreamIdleTimeoutSecs;
    }
    if (_streamIdleTimeoutOptions.contains(parsed)) {
      return parsed;
    }

    var best = _streamIdleTimeoutOptions.first;
    var bestDiff = (parsed - best).abs();
    for (final option in _streamIdleTimeoutOptions.skip(1)) {
      final diff = (parsed - option).abs();
      if (diff < bestDiff) {
        best = option;
        bestDiff = diff;
      }
    }
    return best;
  }

  String _readRecordingRecoveryDuration(Map<String, String> env) {
    final raw = (env['RECORDING_RECOVERY_DURATION'] ?? '').trim().toLowerCase();
    if (raw == 'reset') {
      return 'reset';
    }
    return 'preserve';
  }

  bool _isValidMaxConcurrentRecordings(int value) {
    return value >= _minMaxConcurrentRecordings &&
        value <= _maxMaxConcurrentRecordings;
  }

  int _readMaxConcurrentRecordings(Map<String, String> env) {
    final value = _readBoundedIntFromEnv(
      env,
      'MAX_CONCURRENT_RECORDINGS',
      fallback: _defaultMaxConcurrentRecordings,
      min: _minMaxConcurrentRecordings,
      max: _maxMaxConcurrentRecordings,
    );
    if (_isValidMaxConcurrentRecordings(value)) {
      return value;
    }
    return _defaultMaxConcurrentRecordings;
  }

  int _readMinDiskSpaceGb(Map<String, String> env) {
    final bytes = int.tryParse(env['MIN_DISK_SPACE_BYTES'] ?? '');
    if (bytes == null || bytes < 0) {
      return _defaultMinDiskSpaceGb;
    }

    var best = _diskSpaceOptionsGb.first;
    var bestDiff = (bytes - (best * _bytesPerGb)).abs();
    for (final option in _diskSpaceOptionsGb.skip(1)) {
      final diff = (bytes - (option * _bytesPerGb)).abs();
      if (diff < bestDiff) {
        best = option;
        bestDiff = diff;
      }
    }
    return best;
  }

  String _maxConcurrentRecordingsWarningText(AppLocalizations l10n, int value) {
    if (value >= 11) {
      return l10n.tr('maxConcurrentRecordingsWarningHigh');
    }
    if (value >= 7) {
      return l10n.tr('maxConcurrentRecordingsWarningElevated');
    }
    return l10n.tr('maxConcurrentRecordingsWarning');
  }

  SettingsHintTone _maxConcurrentRecordingsWarningTone(int value) {
    if (value >= 11) {
      return SettingsHintTone.error;
    }
    return SettingsHintTone.warning;
  }

  Future<void> _setMaxRecordingHours(int value) async {
    final next = value.clamp(0, 12);
    await widget.managedEnvironment.set('MAX_RECORDING_HOURS', '$next');
    if (!mounted) return;
    setState(() {
      _maxRecordingHours = next;
    });
  }

  Future<void> _setMinDiskSpaceGb(int value) async {
    if (!_diskSpaceOptionsGb.contains(value)) return;
    final bytes = value * _bytesPerGb;
    await widget.managedEnvironment.set('MIN_DISK_SPACE_BYTES', '$bytes');
    if (!mounted) return;
    setState(() {
      _minDiskSpaceGb = value;
    });
  }

  Future<void> _setMaxRetryMinutes(int value) async {
    if (!_retryMinuteOptions.contains(value)) return;
    await widget.managedEnvironment.set('MAX_RETRY_MINUTES', '$value');
    if (!mounted) return;
    setState(() {
      _maxRetryMinutes = value;
    });
  }

  Future<void> _setStreamIdleTimeoutSecs(int value) async {
    if (!_streamIdleTimeoutOptions.contains(value)) return;
    await widget.managedEnvironment.set('STREAM_IDLE_TIMEOUT', '$value');
    if (!mounted) return;
    setState(() {
      _streamIdleTimeoutSecs = value;
    });
  }

  Future<void> _setRecordingRecoveryDuration(String value) async {
    final normalized = value == 'reset' ? 'reset' : 'preserve';
    await widget.managedEnvironment.set(
      'RECORDING_RECOVERY_DURATION',
      normalized,
    );
    if (!mounted) return;
    setState(() {
      _recordingRecoveryDuration = normalized;
    });
  }

  Future<void> _setMaxConcurrentRecordings(int value) async {
    if (!_isValidMaxConcurrentRecordings(value)) return;
    await widget.managedEnvironment.update((current) {
      current['MAX_CONCURRENT_RECORDINGS'] = '$value';
      if (isSequentialWriteEnabled(current)) {
        applyStorageProtectionEnv(
          env: current,
          protectionEnabled: true,
          maxConcurrent: value,
        );
      }
      return current;
    });
    if (!mounted) return;
    setState(() {
      _maxConcurrentRecordings = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = _maxRecordingHours;
    final disk = _minDiskSpaceGb;
    final retry = _maxRetryMinutes;
    final idle = _streamIdleTimeoutSecs;
    final concurrent = _maxConcurrentRecordings;
    final recovery = _recordingRecoveryDuration;
    if (hours == null ||
        disk == null ||
        retry == null ||
        idle == null ||
        concurrent == null ||
        recovery == null) {
      return const SizedBox(height: 48);
    }

    return SettingsSectionCard(
      icon: Icons.tune_rounded,
      title: l10n.tr('recordingPolicyTitle'),
      description: l10n.tr('recordingPolicyDescription'),
      children: [
        SettingsRangeSlider(
          title: l10n.tr('maxRecordingHoursTitle'),
          description: l10n.tr('maxRecordingHoursDescription'),
          value: hours,
          min: 0,
          max: 12,
          divisions: 12,
          valueLabel: hours == 0
              ? l10n.tr('hoursUnlimitedOption')
              : l10n.tr(
                  'hoursOption',
                  params: {'value': '$hours'},
                ),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _maxRecordingHours = value;
            });
          },
          onChangeEnd: (value) {
            _setMaxRecordingHours(value);
          },
        ),
        const SizedBox(height: 14),
        SettingsOptionSlider(
          title: l10n.tr('minDiskSpaceTitle'),
          description: l10n.tr('minDiskSpaceDescription'),
          options: _diskSpaceOptionsGb,
          value: disk,
          valueLabel: disk == 0
              ? l10n.tr('diskSpaceNoMinimumOption')
              : l10n.tr(
                  'diskSpaceOption',
                  params: {'value': '$disk'},
                ),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _minDiskSpaceGb = value;
            });
          },
          onChangeEnd: (value) {
            _setMinDiskSpaceGb(value);
          },
        ),
        const SizedBox(height: 14),
        SettingsOptionSlider(
          title: l10n.tr('maxRetryMinutesTitle'),
          description: l10n.tr('maxRetryMinutesDescription'),
          options: _retryMinuteOptions,
          value: retry,
          valueLabel: retry == 0
              ? l10n.tr('maxRetryMinutesNoWaitOption')
              : l10n.tr(
                  'minutesOption',
                  params: {'value': '$retry'},
                ),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _maxRetryMinutes = value;
            });
          },
          onChangeEnd: (value) {
            _setMaxRetryMinutes(value);
          },
        ),
        const SizedBox(height: 14),
        SettingsOptionSlider(
          title: l10n.tr('streamIdleTimeoutTitle'),
          description: l10n.tr('streamIdleTimeoutDescription'),
          options: _streamIdleTimeoutOptions,
          value: idle,
          valueLabel: idle == 0
              ? l10n.tr('streamIdleTimeoutOffOption')
              : l10n.tr(
                  'secondsOption',
                  params: {'value': '$idle'},
                ),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _streamIdleTimeoutSecs = value;
            });
          },
          onChangeEnd: (value) {
            _setStreamIdleTimeoutSecs(value);
          },
        ),
        const SizedBox(height: 14),
        SettingsSegmentedField<String>(
          key: const Key('recording_recovery_duration_segments'),
          title: l10n.tr('recordingRecoveryDurationTitle'),
          description: l10n.tr('recordingRecoveryDurationDescription'),
          hint: recovery == 'reset'
              ? l10n.tr('recordingRecoveryDurationResetHint')
              : l10n.tr(
                  'recordingRecoveryDurationPreserveHint',
                ),
          segments: [
            ButtonSegment<String>(
              value: 'preserve',
              label: Text(
                l10n.tr('recordingRecoveryDurationPreserve'),
              ),
            ),
            ButtonSegment<String>(
              value: 'reset',
              label: Text(
                l10n.tr('recordingRecoveryDurationReset'),
              ),
            ),
          ],
          selected: recovery,
          enabled: widget.enabled,
          onSelectionChanged: (value) {
            setState(() {
              _recordingRecoveryDuration = value;
            });
            _setRecordingRecoveryDuration(value);
          },
        ),
        const SizedBox(height: 14),
        SettingsOptionSlider(
          title: l10n.tr('maxConcurrentRecordingsTitle'),
          description: l10n.tr('maxConcurrentRecordingsDescription'),
          hint: SettingsHint(
            tone: _maxConcurrentRecordingsWarningTone(concurrent),
            text: _maxConcurrentRecordingsWarningText(l10n, concurrent),
          ),
          options: _maxConcurrentRecordingOptions,
          value: concurrent,
          valueLabel: l10n.tr(
            'concurrentRecordingOption',
            params: {'value': '$concurrent'},
          ),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _maxConcurrentRecordings = value;
            });
          },
          onChangeEnd: (value) {
            _setMaxConcurrentRecordings(value);
          },
        ),
      ],
    );
  }
}
