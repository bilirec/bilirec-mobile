import 'package:bilirec/app/widgets/settings/settings_option_slider.dart';
import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/managed_environment_store.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';

class SubcheckPolicySection extends StatefulWidget {
  const SubcheckPolicySection({
    required this.enabled,
    required this.managedEnvironment,
    super.key,
  });

  final bool enabled;
  final ManagedEnvironmentStore managedEnvironment;

  @override
  State<SubcheckPolicySection> createState() => _SubcheckPolicySectionState();
}

class _SubcheckPolicySectionState extends State<SubcheckPolicySection> {
  static const List<int> _subcheckMinIntervalOptions = <int>[
    10,
    15,
    30,
    60,
    120,
  ];
  static const List<int> _subcheckRoomsPerShardOptions = <int>[50, 100, 150];
  static const List<int> _subcheckJitterSecsOptions = <int>[0, 2, 5];

  static const int _defaultSubcheckMinIntervalSecs = 60;
  static const int _defaultSubcheckRoomsPerShard = 50;
  static const int _defaultSubcheckJitterSecs = 2;

  int? _subcheckMinIntervalSecs;
  int? _subcheckRoomsPerShard;
  int? _subcheckJitterSecs;

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
      _subcheckMinIntervalSecs = _readSubcheckOptionFromEnv(
        settings,
        'SUBCHECK_MIN_INTERVAL_SECS',
        _subcheckMinIntervalOptions,
        _defaultSubcheckMinIntervalSecs,
      );
      _subcheckRoomsPerShard = _readSubcheckOptionFromEnv(
        settings,
        'SUBCHECK_ROOMS_PER_SHARD',
        _subcheckRoomsPerShardOptions,
        _defaultSubcheckRoomsPerShard,
      );
      _subcheckJitterSecs = _readSubcheckOptionFromEnv(
        settings,
        'SUBCHECK_JITTER_SECS',
        _subcheckJitterSecsOptions,
        _defaultSubcheckJitterSecs,
      );
    });
  }

  int _readSubcheckOptionFromEnv(
    Map<String, String> env,
    String key,
    List<int> options,
    int fallback,
  ) {
    final parsed = int.tryParse(env[key] ?? '');
    if (parsed == null) {
      return fallback;
    }
    if (options.contains(parsed)) {
      return parsed;
    }

    var best = options.first;
    var bestDiff = (parsed - best).abs();
    for (final option in options.skip(1)) {
      final diff = (parsed - option).abs();
      if (diff < bestDiff) {
        best = option;
        bestDiff = diff;
      }
    }
    return best;
  }

  String _subcheckLiveCheckValueLabel(int secs) {
    return l10n.tr('secondsOption', params: {'value': '$secs'});
  }

  String _subcheckManyRoomsValueLabel(int rooms) {
    return l10n.tr('roomsOption', params: {'value': '$rooms'});
  }

  String _subcheckJitterValueLabel(int secs) {
    if (secs == 0) {
      return l10n.tr('subcheckJitterOffOption');
    }
    return l10n.tr('secondsOption', params: {'value': '$secs'});
  }

  Future<void> _setSubcheckMinIntervalSecs(int value) async {
    if (!_subcheckMinIntervalOptions.contains(value)) {
      return;
    }
    await widget.managedEnvironment.update((current) {
      current['SUBCHECK_MIN_INTERVAL_SECS'] = '$value';
      return current;
    });
    if (!mounted) return;
    setState(() {
      _subcheckMinIntervalSecs = value;
    });
  }

  Future<void> _setSubcheckRoomsPerShard(int value) async {
    if (!_subcheckRoomsPerShardOptions.contains(value)) {
      return;
    }
    await widget.managedEnvironment.update((current) {
      current['SUBCHECK_ROOMS_PER_SHARD'] = '$value';
      return current;
    });
    if (!mounted) return;
    setState(() {
      _subcheckRoomsPerShard = value;
    });
  }

  Future<void> _setSubcheckJitterSecs(int value) async {
    if (!_subcheckJitterSecsOptions.contains(value)) {
      return;
    }
    await widget.managedEnvironment.update((current) {
      current['SUBCHECK_JITTER_SECS'] = '$value';
      return current;
    });
    if (!mounted) return;
    setState(() {
      _subcheckJitterSecs = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final interval = _subcheckMinIntervalSecs;
    final rooms = _subcheckRoomsPerShard;
    final jitter = _subcheckJitterSecs;
    if (interval == null || rooms == null || jitter == null) {
      return const SizedBox(height: 48);
    }

    return SettingsSectionCard(
      icon: Icons.podcasts_outlined,
      title: l10n.tr('subcheckPolicyTitle'),
      description: l10n.tr('subcheckPolicyDescription'),
      children: [
        SettingsOptionSlider(
          key: const Key('subcheck_min_interval_slider'),
          title: l10n.tr('subcheckLiveCheckTitle'),
          description: l10n.tr('subcheckLiveCheckDescription'),
          options: _subcheckMinIntervalOptions,
          value: interval,
          valueLabel: _subcheckLiveCheckValueLabel(interval),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _subcheckMinIntervalSecs = value;
            });
          },
          onChangeEnd: _setSubcheckMinIntervalSecs,
        ),
        const SizedBox(height: 14),
        SettingsOptionSlider(
          key: const Key('subcheck_rooms_per_shard_slider'),
          title: l10n.tr('subcheckManyRoomsTitle'),
          description: l10n.tr('subcheckManyRoomsDescription'),
          options: _subcheckRoomsPerShardOptions,
          value: rooms,
          valueLabel: _subcheckManyRoomsValueLabel(rooms),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _subcheckRoomsPerShard = value;
            });
          },
          onChangeEnd: _setSubcheckRoomsPerShard,
        ),
        const SizedBox(height: 14),
        SettingsOptionSlider(
          key: const Key('subcheck_jitter_secs_slider'),
          title: l10n.tr('subcheckRateLimitTitle'),
          description: l10n.tr('subcheckRateLimitDescription'),
          options: _subcheckJitterSecsOptions,
          value: jitter,
          valueLabel: _subcheckJitterValueLabel(jitter),
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {
              _subcheckJitterSecs = value;
            });
          },
          onChangeEnd: _setSubcheckJitterSecs,
        ),
      ],
    );
  }
}
