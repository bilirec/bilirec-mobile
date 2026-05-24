import 'dart:async';
import 'dart:io';

import 'package:bilirec/app/widgets/home_page_language_menu.dart';
import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/app/widgets/service_action_section.dart';
import 'package:bilirec/app/widgets/service_power_button_area.dart';
import 'package:bilirec/app/widgets/service_status_row.dart';
import 'package:bilirec/foreground/bilirec_task_handler.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BilirecTaskHandler());
}

class BilirecHomePage extends StatefulWidget {
  const BilirecHomePage({
    required this.currentLocale,
    required this.onLocaleChanged,
    super.key,
  });

  final Locale currentLocale;
  final Future<void> Function(Locale locale) onLocaleChanged;

  @override
  State<BilirecHomePage> createState() => _BilirecHomePageState();
}

enum ServiceUiState { stopped, starting, running, stopping }

enum ServiceIntent { stopped, running }

class _BilirecHomePageState extends State<BilirecHomePage>
    with WidgetsBindingObserver {
  ServiceUiState _serviceUiState = ServiceUiState.stopped;
  ServiceIntent _desiredServiceState = ServiceIntent.stopped;
  int _latestRequestId = 0;
  int _healthCheckEpoch = 0;
  bool _isIgnoringBatteryOptimizations = false;
  bool _loading = true;
  bool _batteryDialogVisible = false;
  bool _useSsePush = false;
  String _statusKey = 'initializing';
  Map<String, String> _statusParams = const {};
  final TextEditingController _outputDirController = TextEditingController();

  AppLocalizations get l10n => AppLocalizations.of(context);

  bool get _isServiceRunning => _serviceUiState == ServiceUiState.running;
  bool get _isOperationInFlight =>
      _serviceUiState == ServiceUiState.starting ||
      _serviceUiState == ServiceUiState.stopping;

  String get _statusText => l10n.tr(_statusKey, params: _statusParams);

  void _setStatus(String key, {Map<String, String> params = const {}}) {
    _statusKey = key;
    _statusParams = params;
  }

  int _newRequest(ServiceIntent intent) {
    _desiredServiceState = intent;
    _healthCheckEpoch++;
    return ++_latestRequestId;
  }

  bool _isLatestRequest(int requestId) => requestId == _latestRequestId;

  Future<void> _confirmRunning(int requestId) async {
    final epoch = ++_healthCheckEpoch;
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted ||
          !_isLatestRequest(requestId) ||
          _desiredServiceState != ServiceIntent.running ||
          epoch != _healthCheckEpoch) {
        return;
      }

      final running = await _isServiceCoreRunning();
      if (running) {
        if (!mounted ||
            !_isLatestRequest(requestId) ||
            _desiredServiceState != ServiceIntent.running ||
            epoch != _healthCheckEpoch) {
          return;
        }
        setState(() {
          _serviceUiState = ServiceUiState.running;
          _setStatus('backendRunning');
        });
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 700));
    }

    if (!mounted ||
        !_isLatestRequest(requestId) ||
        _desiredServiceState != ServiceIntent.running ||
        epoch != _healthCheckEpoch) {
      return;
    }

    await Preferences.setExpectedRunning(false);
    if (!mounted || !_isLatestRequest(requestId)) return;
    setState(() {
      _serviceUiState = ServiceUiState.stopped;
      _setStatus('backendNoResponse');
    });
  }

  String get _currentLanguageCode =>
      AppLocaleConfig.codeForLocale(widget.currentLocale);

  Future<void> _onLanguageSelected(String code) async {
    await widget.onLocaleChanged(AppLocaleConfig.localeForCode(code));
    if (!mounted) return;
    setState(() {
      _setStatus(_isServiceRunning ? 'backendRunning' : 'backendNotRunning');
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_statusKey.isEmpty) {
      _setStatus('initializing');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _outputDirController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshServiceState();
      _refreshBatteryOptimizationState();
    }
  }

  Future<bool> _isServiceCoreRunning() async {
    try {
      final running = await FlutterForegroundTask.isRunningService;
      final healthy =
          await FlutterForegroundTask.getData(key: coreRunningKey) as bool? ??
              false;
      return running && healthy;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshServiceState() async {
    final running = await _isServiceCoreRunning();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!_isOperationInFlight) {
        _serviceUiState =
            running ? ServiceUiState.running : ServiceUiState.stopped;
      }
      if (!running && !_isOperationInFlight) {
        _setStatus('backendNotRunning');
      }
    });
  }

  Future<void> _bootstrap() async {
    final expectedRunning = await Preferences.getExpectedRunning();
    _outputDirController.text = await Preferences.getOutputDir() ?? '';
    _useSsePush = await Preferences.getEnableSsePush();
    final running = await _isServiceCoreRunning();
    final ignoringOptimization = Platform.isAndroid
        ? await FlutterForegroundTask.isIgnoringBatteryOptimizations
        : true;

    var statusKey = running ? 'backendRunning' : 'backendNotRunning';
    if (expectedRunning && !running) {
      statusKey = 'backendNotRunning';
    }

    if (!mounted) return;
    setState(() {
      _serviceUiState =
          running ? ServiceUiState.running : ServiceUiState.stopped;
      _desiredServiceState =
          running ? ServiceIntent.running : ServiceIntent.stopped;
      _isIgnoringBatteryOptimizations = ignoringOptimization;
      _setStatus(statusKey);
      _loading = false;
    });

    _ensureBatteryDialog();
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;

    final type = data['type']?.toString();
    if (!mounted) return;

    switch (type) {
      case 'service_started':
        if (_desiredServiceState != ServiceIntent.running) {
          break;
        }
        final ok = data['ok'] == true;
        final result = data['result'];
        final requestId = _latestRequestId;
        setState(() {
          if (ok) {
            _serviceUiState = ServiceUiState.starting;
            _setStatus('foregroundStartWaitingCore');
          } else if (result == 1) {
            _serviceUiState = ServiceUiState.stopped;
            _desiredServiceState = ServiceIntent.stopped;
            _setStatus('serviceStartFailedNativeExit');
          } else {
            _serviceUiState = ServiceUiState.stopped;
            _desiredServiceState = ServiceIntent.stopped;
            _setStatus('serviceStartFailedWithCode',
                params: {'code': '$result'});
          }
        });
        if (ok) {
          unawaited(_confirmRunning(requestId));
        }
        break;
      case 'service_stopped':
        if (_desiredServiceState == ServiceIntent.running &&
            _isOperationInFlight) {
          break;
        }
        setState(() {
          _serviceUiState = ServiceUiState.stopped;
          _desiredServiceState = ServiceIntent.stopped;
          _setStatus('backendStopped');
        });
        break;
      case 'backend_dead':
        final stoppedByUser = data['stoppedByUser'] == true;
        setState(() {
          _serviceUiState = ServiceUiState.stopped;
          _desiredServiceState = ServiceIntent.stopped;
          _setStatus('backendNoResponse');
        });
        if (!stoppedByUser) {
          Preferences.setExpectedRunning(false); // fire-and-forget
        }
        break;
      default:
        break;
    }
  }

  Future<void> _openFrontendFromUi() async {
    var opened = false;
    try {
      final Uri uri;
      if (Platform.isAndroid) {
        uri = Uri.parse(
          'intent://app.bilirec.org'
          '#Intent;scheme=https;package=com.android.chrome;action=android.intent.action.VIEW;end',
        );
      } else {
        uri = Uri.parse('https://app.bilirec.org');
      }
      opened = await launchUrl(uri);
    } catch (e) {
      debugPrint('Failed to open frontend: $e');
      opened = false;
    }

    if (!opened) {
      try {
        opened = await launchUrl(
          Uri.parse('https://app.bilirec.org'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }

    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text(l10n.tr('cannotOpenFrontendBrowser'))));
    }
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

  Future<void> _openSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final topInset = mediaQuery.padding.top + 32;
        return Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Material(
                color: Theme.of(sheetContext).colorScheme.surface,
                child: SizedBox(
                  height: mediaQuery.size.height - topInset,
                  child: SettingsDrawerSheet(
                    outputPath: _outputDirController.text,
                    useSsePush: _useSsePush,
                    controlsEnabled:
                        !(_isOperationInFlight || _isServiceRunning),
                    onBrowse: _browseBasePath,
                    onSsePushChanged: _setSsePushEnabled,
                    onClose: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshBatteryOptimizationState() async {
    if (!Platform.isAndroid) return;

    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;

    setState(() {
      _isIgnoringBatteryOptimizations = ignoring;
      // Keep runtime status as the primary message while service is running.
      if (ignoring && !_isServiceRunning) {
        _setStatus('batteryUnrestrictedReady');
      }
    });

    if (ignoring && _batteryDialogVisible) {
      _batteryDialogVisible = false;
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    _ensureBatteryDialog();
  }

  Future<void> _ensureBatteryDialog() async {
    if (!Platform.isAndroid) return;
    if (_isIgnoringBatteryOptimizations || _batteryDialogVisible || !mounted) {
      return;
    }

    _batteryDialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.tr('batteryDialogTitle')),
            content: Text(l10n.tr('batteryDialogContent')),
            actions: [
              FilledButton.tonal(
                onPressed: _requestBatteryUnrestricted,
                child: Text(l10n.tr('goToSettings')),
              ),
            ],
          ),
        );
      },
    );

    _batteryDialogVisible = false;
    if (!_isIgnoringBatteryOptimizations && mounted) {
      _refreshBatteryOptimizationState();
    }
  }

  Future<void> _toggleService(bool enable) async {
    if (!Platform.isAndroid) {
      setState(() {
        _setStatus('androidOnly');
      });
      return;
    }

    if (_isOperationInFlight) {
      return;
    }

    try {
      if (enable) {
        final requestId = _newRequest(ServiceIntent.running);
        setState(() {
          _serviceUiState = ServiceUiState.starting;
          _setStatus('startingService');
        });

        if (!_isLatestRequest(requestId) || !mounted) return;
        await Future.delayed(const Duration(seconds: 1));

        final permission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          final requested =
              await FlutterForegroundTask.requestNotificationPermission();
          if (requested != NotificationPermission.granted) {
            if (!_isLatestRequest(requestId) || !mounted) return;
            setState(() {
              _serviceUiState = ServiceUiState.stopped;
              _desiredServiceState = ServiceIntent.stopped;
              _setStatus('notificationPermissionDenied');
            });
            return;
          }
        }

        final started = await FlutterForegroundTask.startService(
          serviceId: 2026,
          notificationTitle: l10n.tr('notificationTitleRunning'),
          notificationText: l10n.tr('notificationTextRunning'),
          notificationButtons: [
            NotificationButton(
                id: 'stop', text: l10n.tr('notificationButtonStop')),
          ],
          callback: startCallback,
        );

        final ok = started is ServiceRequestSuccess;

        if (!_isLatestRequest(requestId) || !mounted) {
          return;
        }

        await Preferences.setExpectedRunning(ok);
        setState(() {
          _serviceUiState =
              ok ? ServiceUiState.starting : ServiceUiState.stopped;
          if (!ok) {
            _desiredServiceState = ServiceIntent.stopped;
          }
          _setStatus(
              ok ? 'foregroundStartWaitingCore' : 'foregroundStartFailed');
        });
        if (ok) {
          unawaited(_confirmRunning(requestId));
        }
      } else {
        final requestId = _newRequest(ServiceIntent.stopped);
        setState(() {
          _serviceUiState = ServiceUiState.stopping;
        });

        await _yieldToNextFrame();
        if (!_isLatestRequest(requestId) || !mounted) return;

        await Preferences.setStoppedByUser(true);
        await Preferences.setExpectedRunning(false);
        final stopped = await FlutterForegroundTask.stopService();
        final ok = stopped is ServiceRequestSuccess;
        if (!_isLatestRequest(requestId) || !mounted) {
          return;
        }
        setState(() {
          _serviceUiState =
              ok ? ServiceUiState.stopped : ServiceUiState.running;
          _desiredServiceState =
              ok ? ServiceIntent.stopped : ServiceIntent.running;
          _setStatus(ok ? 'backendStopped' : 'stopServiceFailed');
        });
        if (!ok) {
          Preferences.setStoppedByUser(false);
        }
      }
    } catch (e) {
      setState(() {
        _serviceUiState = ServiceUiState.stopped;
        _desiredServiceState = ServiceIntent.stopped;
        _setStatus('serviceOperationFailed', params: {'error': '$e'});
      });
    }
  }

  Future<void> _checkLocalhost8080() async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/'))
          .timeout(const Duration(seconds: 2));
      final response =
          await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      if (!mounted) return;
      final healthy = response.statusCode < 500;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            healthy ? l10n.tr('backendHealthy') : l10n.tr('backendUnhealthy'),
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('backendNoResponseHint'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('backendCannotConnect'))),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _requestBatteryUnrestricted() async {
    if (!Platform.isAndroid) return;
    final granted =
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    if (!granted) {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    }

    await _refreshBatteryOptimizationState();
  }

  Future<void> _yieldToNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isServiceRunning ? Colors.green : Colors.orange;
    final size = MediaQuery.sizeOf(context);
    final actionInFlight = _isOperationInFlight;
    final buttonGradientColors = actionInFlight
        ? const [
            Color(0xFF4F7BFF),
            Color(0xFF57C6FF),
          ]
        : (_isServiceRunning
            ? const [
                Color(0xFF63B3ED),
                Color(0xFF4FD1C5),
              ]
            : const [
                Color(0xFF9AD9FF),
                Color(0xFF7FC8FF),
              ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('controlCenterTitle')),
        actions: [
          HomePageLanguageMenu(
            currentLanguageCode: _currentLanguageCode,
            onSelected: _onLanguageSelected,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    ServicePowerButtonArea(
                      size: size,
                      actionInFlight: actionInFlight,
                      isServiceRunning: _isServiceRunning,
                      isStarting: _serviceUiState == ServiceUiState.starting,
                      isStopping: _serviceUiState == ServiceUiState.stopping,
                      buttonGradientColors: buttonGradientColors,
                      onTap: () => _toggleService(!_isServiceRunning),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ServiceStatusRow(
                            statusColor: statusColor,
                            statusText: _statusText,
                          ),
                          const SizedBox(height: 8),
                          ServiceActionSection(
                            visible: _isServiceRunning,
                            onOpenFrontend: _openFrontendFromUi,
                            onCheckBackendConnection: _checkLocalhost8080,
                          ),
                          SettingsCard(
                            enabled:
                                !(_isOperationInFlight || _isServiceRunning),
                            onPressed: _openSettingsSheet,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
