import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bilirec_service.dart';
import 'l10n/app_localizations.dart';
import 'resource_monitor.dart';

const String _expectedRunningKey = 'expected_service_running';
const String _outputDirKey = 'output_dir';
const String _stoppedByUserKey = 'stopped_by_user';
const String _localeCodeKey = 'locale_code';
const String _coreRunningKey = 'core_running';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _ppkAlertChannel = AndroidNotificationChannel(
  'bilirec_ppk_alert',
  'Bilirec 重要提醒',
  description: '當服務被系統中斷時顯示提醒',
  importance: Importance.high,
);

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BilirecTaskHandler());
}

class BilirecTaskHandler extends TaskHandler {
  late final ResourceMonitor _monitor;

  bool _nativeStarted = false;
  bool _backendWasAlive = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _monitor = ResourceMonitor();
    BilirecService.initialize();
    final appSupport = await getApplicationSupportDirectory();
    final basePath = appSupport.path;
    String? outputDir;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_outputDirKey) ?? '';
      outputDir = saved.isNotEmpty ? saved : null;
      await prefs.setBool(_stoppedByUserKey, false);
    } catch (_) {}
    final result = BilirecService.start(
      StartConfig(basePath: basePath, outputDir: outputDir),
    );
    _nativeStarted = result == 0;
    _backendWasAlive = _nativeStarted;
    FlutterForegroundTask.sendDataToMain({
      'type': 'service_started',
      'ok': _nativeStarted,
      'result': result,
    });
    await FlutterForegroundTask.saveData(
        key: _coreRunningKey, value: _nativeStarted);
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    if (_nativeStarted) {
      final alive = await _pingBackend();
      if (!alive && _backendWasAlive) {
        _backendWasAlive = false;
        final prefs = await SharedPreferences.getInstance();
        final stoppedByUser = prefs.getBool(_stoppedByUserKey) ?? false;
        FlutterForegroundTask.sendDataToMain({
          'type': 'backend_dead',
          'stoppedByUser': stoppedByUser,
        });
        await FlutterForegroundTask.saveData(
            key: _coreRunningKey, value: false);
      } else if (alive && !_backendWasAlive) {
        _backendWasAlive = true;
      }
    }
    FlutterForegroundTask.sendDataToMain({
      'type': 'heartbeat',
      'time': timestamp.toIso8601String(),
    });

    final (cpu, ram) = _monitor.getUsage();
    debugPrint(
        '資源使用 - CPU: ${cpu.toStringAsFixed(2)}%, RAM: ${ram.toStringAsFixed(2)}MB');
    final text =
        await FlutterForegroundTask.getData(key: 'notificationTextRunning')
                as String? ??
            '';
    final recordingLabel =
        await FlutterForegroundTask.getData(key: 'recording') as String? ??
            '錄製中';
    final isRecording = await _isRecording() ? '$recordingLabel • ' : '';
    await FlutterForegroundTask.updateService(
      notificationText:
          '$text\n[ $isRecording${_formatMonitorData(cpu, ram)} ]',
    );
  }

  // 建議的顯示格式轉換邏輯
  String _formatMonitorData(int cpu, int ram) {
    // 1. CPU 超過 50% 時標示為高負載，否則正常
    String cpuDisplay = cpu > 50 ? "CPU: 🔥$cpu%" : "CPU: $cpu%";

    // 2. RAM 簡單顯示 MB，若過大（例如超過 1000MB）可考慮自動轉換為 GB
    String ramDisplay =
        ram > 1000 ? "${(ram / 1024).toStringAsFixed(1)}GB" : "${ram}MB";

    return "$cpuDisplay • RAM: $ramDisplay";
  }

  Future<bool> _isRecording() async {
    final client = HttpClient();
    try {
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/record/list'))
          .timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      final body = await res.transform(utf8.decoder).join();
      final list = jsonDecode(body);
      return list is List && list.isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _pingBackend() async {
    final client = HttpClient();
    try {
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/'))
          .timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      await res.drain<void>();
      return res.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (_nativeStarted) {
      BilirecService.stop();
      _nativeStarted = false;
    }
    FlutterForegroundTask.sendDataToMain({'type': 'service_stopped'});
    await FlutterForegroundTask.saveData(key: _coreRunningKey, value: false);
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) async {
    // Handle critical notification actions in task isolate so they still work
    // after the UI process is swiped away.
    final prefs = await SharedPreferences.getInstance();

    if (id == 'stop') {
      await prefs.setBool(_stoppedByUserKey, true);
      await prefs.setBool(_expectedRunningKey, false);

      if (_nativeStarted) {
        BilirecService.stop();
        _nativeStarted = false;
      }

      await FlutterForegroundTask.stopService();
    }

    FlutterForegroundTask.sendDataToMain({
      'type': 'action_handled',
      'source': 'notification',
      'id': id,
    });
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotifications.initialize(
    const InitializationSettings(android: androidInit),
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_ppkAlertChannel);

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'bilirec_service_channel',
      channelName: 'Bilirec 服務狀態',
      channelDescription: '顯示 Bilirec 服務目前是否運作中',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
      playSound: false,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(15000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(const BilirecApp());
}

class BilirecApp extends StatefulWidget {
  const BilirecApp({super.key});

  @override
  State<BilirecApp> createState() => _BilirecAppState();
}

class _BilirecAppState extends State<BilirecApp> {
  Locale _locale = _devicePreferredLocale();

  static Locale _devicePreferredLocale() {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    return AppLocaleConfig.codeForLocale(deviceLocale) ==
            AppLocaleConfig.simplifiedCode
        ? AppLocaleConfig.simplifiedLocale
        : AppLocaleConfig.traditionalLocale;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeCodeKey);
    if (code == null || !mounted) return;
    setState(() {
      _locale = AppLocaleConfig.localeForCode(code);
    });
  }

  Future<void> _setLocale(Locale locale) async {
    final code = AppLocaleConfig.codeForLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeCodeKey, code);
    if (!mounted) return;
    setState(() {
      _locale = AppLocaleConfig.localeForCode(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bilirec',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8EDBFF)),
        useMaterial3: true,
      ),
      home: BilirecHomePage(
        currentLocale: _locale,
        onLocaleChanged: _setLocale,
      ),
    );
  }
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

    await _setExpectedRunning(false);
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
          await FlutterForegroundTask.getData(key: _coreRunningKey) as bool? ??
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
    final prefs = await SharedPreferences.getInstance();
    final expectedRunning = prefs.getBool(_expectedRunningKey) ?? false;
    _outputDirController.text = prefs.getString(_outputDirKey) ?? '';
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
          _notifyPpkKilled(); // fire-and-forget
          _setExpectedRunning(false); // fire-and-forget
        }
        break;
      case 'action_ack':
        final id = data['id']?.toString();
        if (id == 'notify') {
          setState(() {
            _setStatus('notificationHeartbeatReceived');
          });
        }
        break;
      case 'action_handled':
        final id = data['id']?.toString();
        if (id == 'stop') {
          _newRequest(ServiceIntent.stopped);
          setState(() {
            _serviceUiState = ServiceUiState.stopped;
            _setStatus('serviceStoppedFromNotification');
          });
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
    } catch (_) {
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

  Future<void> _notifyPpkKilled() async {
    await _setExpectedRunning(false);
    await _localNotifications.show(
      2027,
      l10n.tr('ppkKilledTitle'),
      l10n.tr('ppkKilledBody'),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bilirec_ppk_alert',
          'Bilirec 重要提醒',
          channelDescription: '當服務被系統中斷時顯示提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _setExpectedRunning(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expectedRunningKey, value);
  }

  Future<void> _browseBasePath() async {
    final currentDir = _outputDirController.text.trim();
    final initialDir = currentDir.isNotEmpty ? currentDir : null;

    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.tr('selectOutputPath'),
      initialDirectory: initialDir,
    );

    if (selected == null || !mounted) return;

    setState(() {
      _outputDirController.text = selected;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_outputDirKey, selected);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.tr('pathAutoSaved'))));
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

        await _yieldToNextFrame();
        if (!_isLatestRequest(requestId) || !mounted) return;

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

        await FlutterForegroundTask.saveData(
            key: 'notificationTextRunning',
            value: l10n.tr('notificationTextRunning'));
        await FlutterForegroundTask.saveData(
            key: 'recording', value: l10n.tr('recording'));

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

        await _setExpectedRunning(ok);
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

        await SharedPreferences.getInstance().then(
          (p) => p.setBool(_stoppedByUserKey, true),
        );
        await _setExpectedRunning(false);
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
          SharedPreferences.getInstance()
              .then((p) => p.setBool(_stoppedByUserKey, false));
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

  Widget _buildServiceActionSection() {
    final visible = _isServiceRunning;

    // Use AnimatedSize for height-only transition.
    // Hidden state uses full-width SizedBox(height:0) so AnimatedSize only
    // interpolates height (not width), preventing horizontal shrink.
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.fastOutSlowIn,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: visible
            ? Column(
                key: const ValueKey('service-actions-visible'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _openFrontendFromUi,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l10n.tr('openFrontend')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _checkLocalhost8080,
                    icon: const Icon(Icons.lan, size: 16),
                    label: Text(l10n.tr('checkBackendConnection')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5BAEDB),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              )
            // Full-width zero-height box so AnimatedSize only animates height
            : const SizedBox(
                key: ValueKey('service-actions-hidden'), height: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isServiceRunning ? Colors.green : Colors.orange;
    final size = MediaQuery.sizeOf(context);
    final actionInFlight = _isOperationInFlight;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('controlCenterTitle')),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.tr('languageMenuTooltip'),
            initialValue: _currentLanguageCode,
            onSelected: _onLanguageSelected,
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: AppLocaleConfig.traditionalCode,
                child: Text(l10n.tr('languageTraditional')),
              ),
              PopupMenuItem<String>(
                value: AppLocaleConfig.simplifiedCode,
                child: Text(l10n.tr('languageSimplified')),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  _currentLanguageCode == AppLocaleConfig.simplifiedCode
                      ? l10n.tr('languageSimplified')
                      : l10n.tr('languageTraditional'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
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
                    Positioned.fill(
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, -64),
                          child: SizedBox(
                            width: size.width * 0.28,
                            height: size.height * 0.12,
                            child: GestureDetector(
                              onTap: actionInFlight
                                  ? null
                                  : () => _toggleService(!_isServiceRunning),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _isServiceRunning
                                        ? [
                                            const Color(0xFF63B3ED),
                                            const Color(0xFF4FD1C5),
                                          ]
                                        : [
                                            const Color(0xFF9AD9FF),
                                            const Color(0xFF7FC8FF),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF5BAEDB,
                                      ).withValues(alpha: 0.55),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    if (actionInFlight)
                                      BoxShadow(
                                        color: const Color(
                                          0xFFB9E9FF,
                                        ).withValues(alpha: 0.7),
                                        blurRadius: 40,
                                        offset: const Offset(0, 12),
                                      ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    if (actionInFlight)
                                      Positioned.fill(
                                        child: Center(
                                          child: Opacity(
                                            opacity: 0.25,
                                            child: Icon(
                                              Icons.cloud_sync,
                                              size: 80,
                                              color: const Color(0xFFCFF1FF),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Center(
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 280),
                                        child: actionInFlight
                                            ? Column(
                                                key: ValueKey(_serviceUiState),
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _serviceUiState ==
                                                            ServiceUiState
                                                                .stopping
                                                        ? l10n.tr('stop')
                                                        : l10n.tr(
                                                            'startingShort'),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                key: ValueKey(
                                                  _isServiceRunning,
                                                ),
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.power_settings_new,
                                                    size: 40,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _isServiceRunning
                                                        ? l10n.tr('stop')
                                                        : l10n.tr('start'),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
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
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield, color: statusColor),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_statusText)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildServiceActionSection(),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.tr('setOutputPathTitle'),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed:
                                          actionInFlight || _isServiceRunning
                                              ? null
                                              : _browseBasePath,
                                      icon: const Icon(Icons.folder_open),
                                      label: Text(
                                          l10n.tr('browseAndSetOutputPath')),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _outputDirController.text.trim().isEmpty
                                        ? l10n.tr('outputPathUnset')
                                        : l10n.tr(
                                            'outputPathValue',
                                            params: {
                                              'path': _outputDirController.text
                                                  .trim(),
                                            },
                                          ),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
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
