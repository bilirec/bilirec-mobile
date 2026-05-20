import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bilirec_service.dart';
import 'l10n/app_localizations.dart';

const String _expectedRunningKey = 'expected_service_running';
const String _outputDirKey = 'output_dir';
const String _stoppedByUserKey = 'stopped_by_user';
const String _localeCodeKey = 'locale_code';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _ppkAlertChannel = AndroidNotificationChannel(
  'bilirec_ppk_alert',
  'Bilirec Alerts',
  description: 'PPK/system-kill alerts for bilirec foreground service',
  importance: Importance.high,
);

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BilirecTaskHandler());
}

class BilirecTaskHandler extends TaskHandler {
  bool _nativeStarted = false;
  bool _backendWasAlive = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
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
      } else if (alive && !_backendWasAlive) {
        _backendWasAlive = true;
      }
    }
    FlutterForegroundTask.sendDataToMain({
      'type': 'heartbeat',
      'time': timestamp.toIso8601String(),
    });
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
      channelName: 'Bilirec Background Service',
      channelDescription: 'Shows when bilirec backend is running.',
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
  Locale _locale = AppLocaleConfig.traditionalLocale;

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
      title: 'Bilirec Control',
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

class _BilirecHomePageState extends State<BilirecHomePage>
    with WidgetsBindingObserver {
  bool _isServiceRunning = false;
  bool _isStartingService = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _loading = true;
  bool _batteryDialogVisible = false;
  String _statusText = 'Initializing...';
  final TextEditingController _outputDirController = TextEditingController();

  AppLocalizations get l10n => AppLocalizations.of(context);

  String get _currentLanguageCode =>
      AppLocaleConfig.codeForLocale(widget.currentLocale);

  Future<void> _onLanguageSelected(String code) async {
    await widget.onLocaleChanged(AppLocaleConfig.localeForCode(code));
    if (!mounted) return;
    setState(() {
      _statusText = _isServiceRunning
          ? l10n.tr('backendRunning')
          : l10n.tr('backendNotRunning');
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
    if (_statusText == 'Initializing...') {
      _statusText = l10n.tr('initializing');
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

  Future<void> _refreshServiceState() async {
    final running = await FlutterForegroundTask.isRunningService;
    if (!mounted) return;
    setState(() {
      _isServiceRunning = running;
      _loading = false;
      if (!running) {
        _statusText = l10n.tr('backendNotRunning');
      }
    });
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final expectedRunning = prefs.getBool(_expectedRunningKey) ?? false;
    _outputDirController.text = prefs.getString(_outputDirKey) ?? '';
    final running = await FlutterForegroundTask.isRunningService;
    final ignoringOptimization = Platform.isAndroid
        ? await FlutterForegroundTask.isIgnoringBatteryOptimizations
        : true;

    var status =
        running ? l10n.tr('backendRunning') : l10n.tr('backendNotRunning');
    if (expectedRunning && !running) {
      status = l10n.tr('backendNotRunning');
    }

    if (!mounted) return;
    setState(() {
      _isServiceRunning = running;
      _isIgnoringBatteryOptimizations = ignoringOptimization;
      _statusText = status;
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
        final ok = data['ok'] == true;
        final result = data['result'];
        setState(() {
          _isServiceRunning = ok;
          _isStartingService = false;
          if (ok) {
            _statusText = l10n.tr('backendRunning');
          } else if (result == 1) {
            _statusText = l10n.tr('serviceStartFailedNativeExit');
          } else {
            _statusText = l10n.tr(
              'serviceStartFailedWithCode',
              params: {'code': '$result'},
            );
          }
        });
        break;
      case 'service_stopped':
        setState(() {
          _isServiceRunning = false;
          _isStartingService = false;
          _statusText = l10n.tr('backendStopped');
        });
        break;
      case 'backend_dead':
        final stoppedByUser = data['stoppedByUser'] == true;
        setState(() {
          _isServiceRunning = false;
          _statusText = l10n.tr('backendNoResponse');
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
            _statusText = l10n.tr('notificationHeartbeatReceived');
          });
        }
        break;
      case 'action_handled':
        final id = data['id']?.toString();
        if (id == 'stop') {
          setState(() {
            _isServiceRunning = false;
            _isStartingService = false;
            _statusText = l10n.tr('serviceStoppedFromNotification');
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
          'Bilirec Alerts',
          channelDescription:
              'PPK/system-kill alerts for bilirec foreground service',
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

    // must grant external storage permission to control the output directory
    if (!await Permission.manageExternalStorage.request().isGranted) {
      return;
    }

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
        _statusText = l10n.tr('batteryUnrestrictedReady');
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
        _statusText = l10n.tr('androidOnly');
      });
      return;
    }

    try {
      if (enable) {
        setState(() {
          _isStartingService = true;
          _statusText = l10n.tr('startingService');
        });

        final permission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          final requested =
              await FlutterForegroundTask.requestNotificationPermission();
          if (requested != NotificationPermission.granted) {
            setState(() {
              _isStartingService = false;
              _statusText = l10n.tr('notificationPermissionDenied');
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

        await _setExpectedRunning(ok);
        setState(() {
          _isServiceRunning = false;
          _isStartingService = ok;
          _statusText = ok
              ? l10n.tr('foregroundStartWaitingCore')
              : l10n.tr('foregroundStartFailed');
        });
      } else {
        await SharedPreferences.getInstance().then(
          (p) => p.setBool(_stoppedByUserKey, true),
        );
        await _setExpectedRunning(false);
        final stopped = await FlutterForegroundTask.stopService();
        final ok = stopped is ServiceRequestSuccess;
        setState(() {
          _isServiceRunning = !ok;
          _isStartingService = false;
          _statusText =
              ok ? l10n.tr('backendStopped') : l10n.tr('stopServiceFailed');
        });
        if (!ok) {
          SharedPreferences.getInstance()
              .then((p) => p.setBool(_stoppedByUserKey, false));
        }
      }
    } catch (e) {
      setState(() {
        _isStartingService = false;
        _statusText =
            l10n.tr('serviceOperationFailed', params: {'error': '$e'});
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _isServiceRunning ? Colors.green : Colors.orange;
    final size = MediaQuery.sizeOf(context);

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
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: size.width * 0.28,
                          height: size.height * 0.12,
                          child: GestureDetector(
                            onTap: _isStartingService
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
                                  if (_isStartingService)
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
                                  if (_isStartingService)
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
                                      child: _isStartingService
                                          ? Column(
                                              key: const ValueKey('starting'),
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
                                                  l10n.tr('startingShort'),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              key: ValueKey(_isServiceRunning),
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
                                                    fontWeight: FontWeight.bold,
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
                    Row(
                      children: [
                        Icon(Icons.shield, color: statusColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_statusText)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isServiceRunning)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openFrontendFromUi,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(l10n.tr('openFrontend')),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _checkLocalhost8080,
                        icon: const Icon(Icons.lan, size: 16),
                        label: Text(l10n.tr('checkBackendConnection')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5BAEDB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.tr('setOutputPathTitle'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    _isServiceRunning ? null : _browseBasePath,
                                icon: const Icon(Icons.folder_open),
                                label: Text(l10n.tr('browseAndSetOutputPath')),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _outputDirController.text.trim().isEmpty
                                  ? l10n.tr('outputPathUnset')
                                  : l10n.tr(
                                      'outputPathValue',
                                      params: {
                                        'path':
                                            _outputDirController.text.trim(),
                                      },
                                    ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
