import 'dart:io';

import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.settings),
            label: Text(l10n.tr('settings')),
          ),
        ),
      ),
    );
  }
}

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
  static const int _bytesPerGb = 1024 * 1024 * 1024;
  static const List<int> _diskSpaceOptionsGb = <int>[2, 5, 10];
  static const List<int> _retryMinuteOptions = <int>[5, 10, 15, 20, 25, 30];
  static const List<int> _maxConcurrentRecordingOptions = <int>[3, 4, 5, 6];

  static const int _defaultMaxRecordingHours = 5;
  static const int _defaultMinDiskSpaceGb = 5;
  static const int _defaultMaxRetryMinutes = 10;
  static const int _defaultMaxConcurrentRecordings = 3;

  bool _useSsePush = false;
  bool _useAntiSleep = false;
  bool _downloadingBootstrapLog = false;
  bool _convertToMp4 = false;
  bool _deleteSourceAfterConvert = false;
  bool _ffmpegAllowDuringRecording = false;
  int _ffmpegAllowDuringRecordingMaxActive = 1;
  int _maxRecordingHours = _defaultMaxRecordingHours;
  int _minDiskSpaceGb = _defaultMinDiskSpaceGb;
  int _maxRetryMinutes = _defaultMaxRetryMinutes;
  int _maxConcurrentRecordings = _defaultMaxConcurrentRecordings;
  Map<String, String> _managedEnvironmentSettings = <String, String>{};
  Map<String, String> _developEnvironmentSettings = <String, String>{};

  final TextEditingController _outputDirController = TextEditingController();

  AppLocalizations get l10n => AppLocalizations.of(context);

  void _showToast(
    String message, {
    AppToastLocation location = AppToastLocation.top,
  }) {
    showAppToast(
      context,
      message,
      animation: AppToastAnimation.fade,
      location: location,
      edgeDistance: 72,
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final outputPath = await Preferences.getOutputDir() ?? '';
    final useSsePush = await Preferences.getEnableSsePush();
    final useAntiSleep = await Preferences.getEnableAntiSleep();
    final managedEnvironmentSettings =
        await Preferences.getManagedEnvironmentSettings();
    final developEnvironmentSettings =
        await Preferences.getDevelopEnvironmentSettings();
    if (!mounted) return;
    _outputDirController.text = outputPath;
    setState(() {
      _useSsePush = useSsePush;
      _useAntiSleep = useAntiSleep;
      _managedEnvironmentSettings = managedEnvironmentSettings;
      _developEnvironmentSettings = developEnvironmentSettings;
      _maxRecordingHours = _readMaxRecordingHours(managedEnvironmentSettings);
      _minDiskSpaceGb = _readMinDiskSpaceGb(managedEnvironmentSettings);
      _maxRetryMinutes = _readMaxRetryMinutes(managedEnvironmentSettings);
      _maxConcurrentRecordings =
          _readMaxConcurrentRecordings(managedEnvironmentSettings);
      _convertToMp4 =
          _readBoolFromEnv(managedEnvironmentSettings, 'CONVERT_TO_MP4');
      _deleteSourceAfterConvert = _readBoolFromEnv(
        managedEnvironmentSettings,
        'DELETE_SOURCE_AFTER_CONVERT',
      );
      _ffmpegAllowDuringRecording = _readBoolFromEnv(
        managedEnvironmentSettings,
        'FFMPEG_ALLOW_DURING_RECORDING',
      );
      _ffmpegAllowDuringRecordingMaxActive = _readBoundedIntFromEnv(
        managedEnvironmentSettings,
        'FFMPEG_ALLOW_DURING_RECORDING_MAX_ACTIVE_RECORDINGS',
        fallback: 1,
        min: 0,
        max: 5,
      );
    });
  }

  @override
  void dispose() {
    _outputDirController.dispose();
    super.dispose();
  }

  Future<String?> _browseBasePath() async {
    final currentDir = _outputDirController.text.trim();
    final initialDir = currentDir.isNotEmpty ? currentDir : null;

    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.tr('selectOutputPath'),
      initialDirectory: initialDir,
    );

    if (selected == null || !mounted) return null;

    setState(() {
      _outputDirController.text = selected;
    });

    await Preferences.setOutputDir(selected);
    if (!mounted) return null;
    return selected;
  }

  Future<void> _setSsePushEnabled(bool enabled) async {
    await Preferences.setEnableSsePush(enabled);
    if (!mounted) return;
    setState(() {
      _useSsePush = enabled;
    });
  }

  Future<void> _setAntiSleepEnabled(bool enabled) async {
    await Preferences.setEnableAntiSleep(enabled);
    if (!mounted) return;
    setState(() {
      _useAntiSleep = enabled;
    });
  }

  bool _readBoolFromEnv(
    Map<String, String> env,
    String key,
  ) {
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

    final stepped = ((parsed / 5).round() * 5).clamp(5, 30);
    if (_retryMinuteOptions.contains(stepped)) {
      return stepped;
    }
    return fallback;
  }

  int _readMaxConcurrentRecordings(Map<String, String> env) {
    final value = _readBoundedIntFromEnv(
      env,
      'MAX_CONCURRENT_RECORDINGS',
      fallback: _defaultMaxConcurrentRecordings,
      min: _maxConcurrentRecordingOptions.first,
      max: _maxConcurrentRecordingOptions.last,
    );
    if (_maxConcurrentRecordingOptions.contains(value)) {
      return value;
    }
    return _defaultMaxConcurrentRecordings;
  }

  int _readMinDiskSpaceGb(Map<String, String> env) {
    final bytes = int.tryParse(env['MIN_DISK_SPACE_BYTES'] ?? '');
    if (bytes == null || bytes <= 0) {
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

  Future<void> _setManagedEnvironmentSetting(
    String key,
    String value,
  ) async {
    final updated = <String, String>{
      ..._managedEnvironmentSettings,
      key: value
    };
    await Preferences.setManagedEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _managedEnvironmentSettings = updated;
    });
  }

  Future<void> _setMaxRecordingHours(int value) async {
    final next = value.clamp(0, 12);
    await _setManagedEnvironmentSetting('MAX_RECORDING_HOURS', '$next');
    if (!mounted) return;
    setState(() {
      _maxRecordingHours = next;
    });
  }

  Future<void> _setMinDiskSpaceGb(int value) async {
    if (!_diskSpaceOptionsGb.contains(value)) return;
    final bytes = value * _bytesPerGb;
    await _setManagedEnvironmentSetting('MIN_DISK_SPACE_BYTES', '$bytes');
    if (!mounted) return;
    setState(() {
      _minDiskSpaceGb = value;
    });
  }

  Future<void> _setMaxRetryMinutes(int value) async {
    if (!_retryMinuteOptions.contains(value)) return;
    await _setManagedEnvironmentSetting('MAX_RETRY_MINUTES', '$value');
    if (!mounted) return;
    setState(() {
      _maxRetryMinutes = value;
    });
  }

  Future<void> _setMaxConcurrentRecordings(int value) async {
    if (!_maxConcurrentRecordingOptions.contains(value)) return;
    await _setManagedEnvironmentSetting('MAX_CONCURRENT_RECORDINGS', '$value');
    if (!mounted) return;
    setState(() {
      _maxConcurrentRecordings = value;
    });
  }

  Future<void> _setConvertToMp4Enabled(bool enabled) async {
    final updated = <String, String>{
      ..._managedEnvironmentSettings,
      'CONVERT_TO_MP4': '$enabled',
      if (!enabled) 'DELETE_SOURCE_AFTER_CONVERT': 'false',
    };
    await Preferences.setManagedEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _managedEnvironmentSettings = updated;
      _convertToMp4 = enabled;
      if (!enabled) {
        _deleteSourceAfterConvert = false;
      }
    });
  }

  Future<void> _setDeleteSourceAfterConvertEnabled(bool enabled) async {
    final updated = <String, String>{
      ..._managedEnvironmentSettings,
      'DELETE_SOURCE_AFTER_CONVERT': '$enabled',
    };
    await Preferences.setManagedEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _managedEnvironmentSettings = updated;
      _deleteSourceAfterConvert = enabled;
    });
  }

  Future<void> _setFfmpegAllowDuringRecordingEnabled(bool enabled) async {
    final updated = <String, String>{
      ..._managedEnvironmentSettings,
      'FFMPEG_ALLOW_DURING_RECORDING': '$enabled',
      if (!enabled) 'FFMPEG_ALLOW_DURING_RECORDING_MAX_ACTIVE_RECORDINGS': '1',
    };
    await Preferences.setManagedEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _managedEnvironmentSettings = updated;
      _ffmpegAllowDuringRecording = enabled;
      if (!enabled) {
        _ffmpegAllowDuringRecordingMaxActive = 1;
      }
    });
  }

  Future<void> _setFfmpegAllowDuringRecordingMaxActive(int value) async {
    final bounded = value.clamp(0, 5);
    await _setManagedEnvironmentSetting(
      'FFMPEG_ALLOW_DURING_RECORDING_MAX_ACTIVE_RECORDINGS',
      '$bounded',
    );
    if (!mounted) return;
    setState(() {
      _ffmpegAllowDuringRecordingMaxActive = bounded;
    });
  }

  int _optionFromSlider(List<int> options, double sliderValue) {
    final index = sliderValue.round().clamp(0, options.length - 1);
    return options[index];
  }

  double _sliderFromOption(List<int> options, int value) {
    final index = options.indexOf(value);
    return (index >= 0 ? index : 0).toDouble();
  }

  Future<void> _upsertEnvironmentSetting({
    required String key,
    required String value,
    String? replaceKey,
  }) async {
    final normalizedKey = key.trim();
    final normalizedValue = value.trim();
    if (normalizedKey.isEmpty) {
      if (!mounted) return;
      _showToast(l10n.tr('environmentKeyRequired'));
      return;
    }

    final updated = <String, String>{..._developEnvironmentSettings};
    if (replaceKey != null && replaceKey != normalizedKey) {
      updated.remove(replaceKey);
    }
    updated[normalizedKey] = normalizedValue;
    await Preferences.setDevelopEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _developEnvironmentSettings = updated;
    });
  }

  Future<void> _showEnvironmentSettingDialog({String? initialKey}) async {
    final initialValue =
        initialKey == null ? '' : _developEnvironmentSettings[initialKey] ?? '';
    var keyText = initialKey ?? '';
    var valueText = initialValue;

    final result = await showDialog<_EnvironmentSettingInput>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            initialKey == null
                ? l10n.tr('addEnvironmentSetting')
                : l10n.tr('editEnvironmentSetting'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('env_key_input'),
                autofocus: true,
                textInputAction: TextInputAction.next,
                initialValue: keyText,
                onChanged: (value) => keyText = value,
                decoration: InputDecoration(
                  labelText: l10n.tr('environmentKeyLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('env_value_input'),
                textInputAction: TextInputAction.done,
                initialValue: valueText,
                onChanged: (value) => valueText = value,
                onFieldSubmitted: (_) {
                  Navigator.of(dialogContext).pop(
                    _EnvironmentSettingInput(
                      key: keyText,
                      value: valueText,
                    ),
                  );
                },
                decoration: InputDecoration(
                  labelText: l10n.tr('environmentValueLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  _EnvironmentSettingInput(
                    key: keyText,
                    value: valueText,
                  ),
                );
              },
              child: Text(l10n.tr('saveEnvironmentSetting')),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    await _upsertEnvironmentSetting(
      key: result.key,
      value: result.value,
      replaceKey: initialKey,
    );
  }

  Future<void> _removeEnvironmentSetting(String key) async {
    if (!_developEnvironmentSettings.containsKey(key)) {
      return;
    }
    final updated = <String, String>{..._developEnvironmentSettings}
      ..remove(key);
    await Preferences.setDevelopEnvironmentSettings(updated);
    if (!mounted) return;
    setState(() {
      _developEnvironmentSettings = updated;
    });
  }

  Future<void> _downloadBootstrapLog() async {
    if (_downloadingBootstrapLog) return;
    setState(() {
      _downloadingBootstrapLog = true;
    });

    try {
      final appSupport = await getApplicationSupportDirectory();
      final sourceDir = Directory(appSupport.path);

      if (!await sourceDir.exists()) {
        if (!mounted) return;
        _showToast(
          '⚠️ ${l10n.tr('downloadBootstrapLogNotFound')}',
          location: AppToastLocation.bottom,
        );
        return;
      }

      // 找出所有 bootstrap*.log 分片（lumberjack 輪轉後產生的歷史片段 + 當前主日誌）
      final entities = await sourceDir.list().toList();
      final logFiles = entities.whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        // 只抓 bootstrap*.log，排除 .gz 或其他無關檔案
        return name.startsWith('bootstrap') && name.endsWith('.log');
      }).toList();

      if (logFiles.isEmpty) {
        if (!mounted) return;
        _showToast(
          '⚠️ ${l10n.tr('downloadBootstrapLogNotFound')}',
          location: AppToastLocation.bottom,
        );
        return;
      }

      // 依檔名排序：lumberjack 歷史檔帶 `-YYYY-MM-DD` 時間戳，
      // ASCII '-'(45) < '.'(46)，所以 bootstrap-2026-... 排在 bootstrap.log 之前，
      // 結果即「由舊到新」，當前主日誌永遠排最後。
      logFiles.sort((a, b) => a.path.compareTo(b.path));

      if (!mounted) return;
      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.tr('selectLogDownloadPath'),
      );
      if (selectedDir == null || selectedDir.trim().isEmpty) {
        return;
      }

      final now = DateTime.now();
      final timestamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final targetPath =
          '$selectedDir${Platform.pathSeparator}bootstrap_$timestamp.log';

      // 串流合併：逐一將每個分片寫入目標檔案，避免一次性讀入記憶體
      final targetFile = File(targetPath);
      final sink = targetFile.openWrite(mode: FileMode.write);
      try {
        for (final file in logFiles) {
          await sink.addStream(file.openRead());
          // 確保每個分片接縫有換行，防止最後一行與下一片黏連
          sink.writeln();
        }
      } finally {
        await sink.close();
      }

      if (!mounted) return;
      _showToast(
        l10n.tr(
          'downloadBootstrapLogSuccess',
          params: {
            'path': targetPath,
            'count': '${logFiles.length}',
          },
        ),
        location: AppToastLocation.bottom,
      );
    } catch (e) {
      if (!mounted) return;
      _showToast(
        l10n.tr(
          'downloadBootstrapLogFailed',
          params: {'error': '$e'},
        ),
        location: AppToastLocation.bottom,
      );
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
    final trimmedOutputPath = _outputDirController.text.trim();
    final outputPathText = trimmedOutputPath.isEmpty
        ? l10n.tr('outputPathUnset')
        : trimmedOutputPath;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ffmpegControlsEnabled = widget.controlsEnabled && _convertToMp4;
    final ffmpegLimitEnabled =
        ffmpegControlsEnabled && _ffmpegAllowDuringRecording;
    final customEnvironmentEntries = _developEnvironmentSettings.entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.folder_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.tr('storagePathTitle'),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            outputPathText,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed:
                                widget.controlsEnabled ? _browseBasePath : null,
                            child: Text(l10n.tr('changePath')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.tr('ssePushSwitchTitle'),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.tr('ssePushDescription'),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Switch.adaptive(
                                value: _useSsePush,
                                onChanged: widget.controlsEnabled
                                    ? _setSsePushEnabled
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.tr('ssePushHint'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.tr('antiSleepTitle'),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.tr('antiSleepDescription'),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Switch.adaptive(
                                value: _useAntiSleep,
                                onChanged: widget.controlsEnabled
                                    ? _setAntiSleepEnabled
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _useAntiSleep
                                      ? l10n.tr('antiSleepEnabledHint')
                                      : l10n.tr('antiSleepDisabledHint'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune_rounded),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.tr('recordingPolicyTitle'),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.tr('recordingPolicyDescription'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.tr('maxRecordingHoursTitle'),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr('maxRecordingHoursDescription'),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _maxRecordingHours == 0
                                ? l10n.tr('hoursUnlimitedOption')
                                : l10n.tr(
                                    'hoursOption',
                                    params: {'value': '$_maxRecordingHours'},
                                  ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            // Keep line metrics stable between different label texts.
                            strutStyle: StrutStyle(
                              fontSize: theme.textTheme.bodySmall?.fontSize,
                              height: 1.25,
                              forceStrutHeight: true,
                            ),
                          ),
                          Slider(
                            value: _maxRecordingHours.toDouble(),
                            min: 0,
                            max: 12,
                            divisions: 12,
                            label: _maxRecordingHours == 0
                                ? l10n.tr('hoursUnlimitedOption')
                                : l10n.tr(
                                    'hoursOption',
                                    params: {'value': '$_maxRecordingHours'},
                                  ),
                            onChanged: widget.controlsEnabled
                                ? (value) {
                                    setState(() {
                                      _maxRecordingHours = value.round();
                                    });
                                  }
                                : null,
                            onChangeEnd: widget.controlsEnabled
                                ? (value) {
                                    _setMaxRecordingHours(value.round());
                                  }
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.tr('minDiskSpaceTitle'),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr('minDiskSpaceDescription'),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr(
                              'diskSpaceOption',
                              params: {'value': '$_minDiskSpaceGb'},
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Slider(
                            value: _sliderFromOption(
                              _diskSpaceOptionsGb,
                              _minDiskSpaceGb,
                            ),
                            min: 0,
                            max: (_diskSpaceOptionsGb.length - 1).toDouble(),
                            divisions: _diskSpaceOptionsGb.length - 1,
                            label: l10n.tr(
                              'diskSpaceOption',
                              params: {'value': '$_minDiskSpaceGb'},
                            ),
                            onChanged: widget.controlsEnabled
                                ? (value) {
                                    setState(() {
                                      _minDiskSpaceGb = _optionFromSlider(
                                        _diskSpaceOptionsGb,
                                        value,
                                      );
                                    });
                                  }
                                : null,
                            onChangeEnd: widget.controlsEnabled
                                ? (value) {
                                    _setMinDiskSpaceGb(
                                      _optionFromSlider(
                                        _diskSpaceOptionsGb,
                                        value,
                                      ),
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.tr('maxRetryMinutesTitle'),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr('maxRetryMinutesDescription'),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr(
                              'minutesOption',
                              params: {'value': '$_maxRetryMinutes'},
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Slider(
                            value: _sliderFromOption(
                              _retryMinuteOptions,
                              _maxRetryMinutes,
                            ),
                            min: 0,
                            max: (_retryMinuteOptions.length - 1).toDouble(),
                            divisions: _retryMinuteOptions.length - 1,
                            label: l10n.tr(
                              'minutesOption',
                              params: {'value': '$_maxRetryMinutes'},
                            ),
                            onChanged: widget.controlsEnabled
                                ? (value) {
                                    setState(() {
                                      _maxRetryMinutes = _optionFromSlider(
                                        _retryMinuteOptions,
                                        value,
                                      );
                                    });
                                  }
                                : null,
                            onChangeEnd: widget.controlsEnabled
                                ? (value) {
                                    _setMaxRetryMinutes(
                                      _optionFromSlider(
                                        _retryMinuteOptions,
                                        value,
                                      ),
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.tr('maxConcurrentRecordingsTitle'),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr('maxConcurrentRecordingsDescription'),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.tr('maxConcurrentRecordingsWarning'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr(
                              'concurrentRecordingOption',
                              params: {'value': '$_maxConcurrentRecordings'},
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Slider(
                            value: _sliderFromOption(
                              _maxConcurrentRecordingOptions,
                              _maxConcurrentRecordings,
                            ),
                            min: 0,
                            max: (_maxConcurrentRecordingOptions.length - 1)
                                .toDouble(),
                            divisions:
                                _maxConcurrentRecordingOptions.length - 1,
                            label: l10n.tr(
                              'concurrentRecordingOption',
                              params: {'value': '$_maxConcurrentRecordings'},
                            ),
                            onChanged: widget.controlsEnabled
                                ? (value) {
                                    setState(() {
                                      _maxConcurrentRecordings =
                                          _optionFromSlider(
                                        _maxConcurrentRecordingOptions,
                                        value,
                                      );
                                    });
                                  }
                                : null,
                            onChangeEnd: widget.controlsEnabled
                                ? (value) {
                                    _setMaxConcurrentRecordings(
                                      _optionFromSlider(
                                        _maxConcurrentRecordingOptions,
                                        value,
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.tr('conversionPolicyTitle'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tr('conversionPolicyDescription'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.tr('convertToMp4Title')),
                              subtitle: Text(
                                l10n.tr('convertToMp4SecondaryDescription'),
                              ),
                              value: _convertToMp4,
                              onChanged: widget.controlsEnabled
                                  ? _setConvertToMp4Enabled
                                  : null,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.tr('deleteSourceAfterConvertTitle'),
                              ),
                              subtitle: Text(
                                l10n.tr('deleteSourceAfterConvertDescription'),
                              ),
                              value: _deleteSourceAfterConvert,
                              onChanged:
                                  (widget.controlsEnabled && _convertToMp4)
                                      ? _setDeleteSourceAfterConvertEnabled
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  l10n.tr('ffmpegAllowDuringRecordingTitle')),
                              subtitle: Text(
                                l10n.tr(
                                    'ffmpegAllowDuringRecordingDescription'),
                              ),
                              value: _ffmpegAllowDuringRecording,
                              onChanged: ffmpegControlsEnabled
                                  ? _setFfmpegAllowDuringRecordingEnabled
                                  : null,
                            ),
                          ),
                          if (_ffmpegAllowDuringRecording)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l10n.tr(
                                      'ffmpegAllowDuringRecordingWarning',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: ffmpegLimitEnabled ? 1.0 : 0.5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.tr('ffmpegMaxActiveRecordingsTitle'),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: ffmpegLimitEnabled
                                        ? null
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.tr(
                                      'ffmpegMaxActiveRecordingsDescription'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: ffmpegLimitEnabled
                                        ? null
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _ffmpegAllowDuringRecordingMaxActive == 0
                                      ? l10n
                                          .tr('ffmpegMaxActiveUnlimitedOption')
                                      : l10n.tr(
                                          'ffmpegMaxActiveOption',
                                          params: {
                                            'value':
                                                '$_ffmpegAllowDuringRecordingMaxActive'
                                          },
                                        ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  strutStyle: StrutStyle(
                                    fontSize:
                                        theme.textTheme.bodySmall?.fontSize,
                                    height: 1.25,
                                    forceStrutHeight: true,
                                  ),
                                ),
                                Slider(
                                  value: _ffmpegAllowDuringRecordingMaxActive
                                      .toDouble(),
                                  min: 0,
                                  max: 5,
                                  divisions: 5,
                                  label: _ffmpegAllowDuringRecordingMaxActive ==
                                          0
                                      ? l10n
                                          .tr('ffmpegMaxActiveUnlimitedOption')
                                      : l10n.tr(
                                          'ffmpegMaxActiveOption',
                                          params: {
                                            'value':
                                                '$_ffmpegAllowDuringRecordingMaxActive'
                                          },
                                        ),
                                  onChanged: ffmpegLimitEnabled
                                      ? (value) {
                                          setState(() {
                                            _ffmpegAllowDuringRecordingMaxActive =
                                                value.round();
                                          });
                                        }
                                      : null,
                                  onChangeEnd: ffmpegLimitEnabled
                                      ? (value) {
                                          _setFfmpegAllowDuringRecordingMaxActive(
                                            value.round(),
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.tr('developerSettingsTitle'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tr('developerSectionDescription'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.code_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.tr('environmentSettingsTitle'),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.tr('environmentSettingsWarning'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: widget.controlsEnabled
                                ? () => _showEnvironmentSettingDialog()
                                : null,
                            icon: const Icon(Icons.add),
                            label: Text(l10n.tr('addEnvironmentSetting')),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.tr('savedEnvironmentSettingsTitle'),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          if (customEnvironmentEntries.isEmpty)
                            Text(
                              l10n.tr('environmentSettingsEmpty'),
                              style: theme.textTheme.bodySmall,
                            )
                          else
                            ...customEnvironmentEntries.map((entry) {
                              // 在這裡包上 Material
                              return Material(
                                color: Colors.transparent,
                                // 保持透明，露出底下的 DecoratedBox 顏色
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.key),
                                  subtitle: Text(
                                    entry.value.isEmpty
                                        ? l10n.tr('environmentValueEmpty')
                                        : entry.value,
                                  ),
                                  trailing: IconButton(
                                    onPressed: widget.controlsEnabled
                                        ? () =>
                                            _removeEnvironmentSetting(entry.key)
                                        : null,
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip:
                                        l10n.tr('removeEnvironmentSetting'),
                                  ),
                                  onTap: widget.controlsEnabled
                                      ? () => _showEnvironmentSettingDialog(
                                          initialKey: entry.key)
                                      : null,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.tr('bootstrapLogTitle'),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.tr('bootstrapLogDescription'),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: _downloadingBootstrapLog
                                ? null
                                : _downloadBootstrapLog,
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentSettingInput {
  const _EnvironmentSettingInput({required this.key, required this.value});

  final String key;
  final String value;
}
