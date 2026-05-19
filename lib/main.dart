import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bilirec_service.dart';

const String _expectedRunningKey = 'expected_service_running';
const String _basePathKey = 'base_path';
const String _stoppedByUserKey = 'stopped_by_user';

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
    String basePath;
    try {
      final prefs = await SharedPreferences.getInstance();
      basePath = prefs.getString(_basePathKey) ?? '';
      await prefs.setBool(_stoppedByUserKey, false);
    } catch (_) {
      final appSupport = await getApplicationSupportDirectory();
      basePath = appSupport.path;
    }
    final result = BilirecService.start(StartConfig(basePath: basePath));
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
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'action_ack',
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
        AndroidFlutterLocalNotificationsPlugin
      >()
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

class BilirecApp extends StatelessWidget {
  const BilirecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bilirec Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8EDBFF)),
        useMaterial3: true,
      ),
      home: const BilirecHomePage(),
    );
  }
}

class BilirecHomePage extends StatefulWidget {
  const BilirecHomePage({super.key});

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
  String _statusText = '初始化中...';
  final TextEditingController _basePathController = TextEditingController();
  final List<String> _allowedBaseRoots = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _basePathController.dispose();
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
        _statusText = 'Bilirec 後端未運行';
      }
    });
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final expectedRunning = prefs.getBool(_expectedRunningKey) ?? false;
    _basePathController.text = prefs.getString(_basePathKey) ?? '';
    final running = await FlutterForegroundTask.isRunningService;
    final ignoringOptimization = Platform.isAndroid
        ? await FlutterForegroundTask.isIgnoringBatteryOptimizations
        : true;
    await _loadAllowedBaseRoots();

    if (_basePathController.text.trim().isEmpty && _allowedBaseRoots.isNotEmpty) {
      final defaultPath = _allowedBaseRoots.first;
      _basePathController.text = defaultPath;
      await prefs.setString(_basePathKey, defaultPath);
    }

    var status = running ? 'Bilirec 後端運行中' : 'Bilirec 後端未運行';
    if (expectedRunning && !running) {
      status = 'Bilirec 後端未運行';
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

  Future<void> _loadAllowedBaseRoots() async {
    final roots = <String>{};
    final appSupport = await getApplicationSupportDirectory();
    roots.add(_normalizePath(appSupport.path));

    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        roots.add(_normalizePath(external.path));
      }
      final extras = await getExternalStorageDirectories();
      if (extras != null) {
        for (final dir in extras) {
          roots.add(_normalizePath(dir.path));
        }
      }
    }

    _allowedBaseRoots
      ..clear()
      ..addAll(roots.where((r) => r.isNotEmpty));
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
            _statusText = 'Bilirec 後端運行中';
          } else if (result == 1) {
            _statusText = '服務啟動失敗：native 核心返回 exit code 1';
          } else {
            _statusText = '服務啟動失敗，代碼: $result';
          }
        });
        break;
      case 'service_stopped':
        setState(() {
          _isServiceRunning = false;
          _isStartingService = false;
          _statusText = 'Bilirec 後端已停止';
        });
        break;
      case 'backend_dead':
        final stoppedByUser = data['stoppedByUser'] == true;
        setState(() {
          _isServiceRunning = false;
          _statusText = 'Bilirec 後端無回應（可能被系統終止）';
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
            _statusText = '已收到通知服務心跳';
          });
        } else if (id != null && (id == 'frontend' || id == 'stop')) {
          _handleNotificationAction(id);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _handleNotificationAction(String action) async {
    if (action == 'frontend') {
      try {
        final Uri uri;
        if (Platform.isAndroid) {
          uri = Uri.parse(
            'intent://app.bilirec.org'
            '#Intent;scheme=https;package=com.android.chrome;end',
          );
        } else {
          uri = Uri.parse('https://app.bilirec.org');
        }
        await launchUrl(uri);
      } catch (_) {
        try {
          await launchUrl(
            Uri.parse('https://app.bilirec.org'),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}
      }
    } else if (action == 'stop') {
      await _toggleService(false);
    }
  }

  Future<void> _notifyPpkKilled() async {
    await _setExpectedRunning(false);
    await _localNotifications.show(
      2027,
      'Bilirec 服務已被系統終止',
      '偵測到前景服務異常中斷（疑似 PPK），請重新啟動並確認電池無限制。',
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

  String _normalizePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  bool _isPathAllowed(String path) {
    final normalized = _normalizePath(path);
    return _allowedBaseRoots.any(
      (root) => normalized == root || normalized.startsWith('$root/'),
    );
  }

  Future<void> _browseBasePath() async {
    final currentBase = _basePathController.text.trim();
    final initialBase = currentBase.isNotEmpty
        ? currentBase
        : (_allowedBaseRoots.isNotEmpty ? _allowedBaseRoots.first : null);

    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '選擇 Base Path',
      initialDirectory: initialBase,
    );

    if (selected == null || !mounted) return;

    if (!_isPathAllowed(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('路徑不支援前景服務，請選擇以下路徑底下: ${_allowedBaseRoots.join(' | ')}')),
      );
      return;
    }

    setState(() {
      _basePathController.text = selected;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_basePathKey, selected);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已自動儲存路徑')));
  }

  Future<void> _refreshBatteryOptimizationState() async {
    if (!Platform.isAndroid) return;

    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;

    setState(() {
      _isIgnoringBatteryOptimizations = ignoring;
      if (ignoring) {
        _statusText = '已設定電池無限制，bilirec 更不容易被系統終止';
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
            title: const Text('需要電池無限制'),
            content: const Text(
              '請將 bilirec 設為電池無限制，否則後台服務可能被系統關閉。\n\n完成後請回到 App。',
            ),
            actions: [
              FilledButton.tonal(
                onPressed: _requestBatteryUnrestricted,
                child: const Text('前往設定'),
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
        _statusText = '目前僅支援 Android 前景服務';
      });
      return;
    }

    try {
      if (enable) {
        setState(() {
          _isStartingService = true;
          _statusText = '正在啟動服務...';
        });

        final permission = await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          final requested =
              await FlutterForegroundTask.requestNotificationPermission();
          if (requested != NotificationPermission.granted) {
            setState(() {
              _isStartingService = false;
              _statusText = '通知權限未開啟，無法啟動前景服務';
            });
            return;
          }
        }

        final started = await FlutterForegroundTask.startService(
          serviceId: 2026,
          notificationTitle: 'Bilirec 後端正在運行',
          notificationText: '後台錄製服務運行中',
          notificationButtons: [
            const NotificationButton(id: 'frontend', text: '啟動前端'),
            const NotificationButton(id: 'stop', text: '停止服務'),
          ],
          callback: startCallback,
        );
        final ok = started is ServiceRequestSuccess;

        await _setExpectedRunning(ok);
        setState(() {
          _isServiceRunning = false;
          _isStartingService = ok;
          _statusText = ok ? '前景服務已啟動，等待核心回報...' : '前景服務啟動失敗';
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
          _statusText = ok ? 'Bilirec 後端已停止' : '停止服務失敗';
        });
        if (!ok) {
          SharedPreferences.getInstance()
              .then((p) => p.setBool(_stoppedByUserKey, false));
        }
      }
    } catch (e) {
      setState(() {
        _isStartingService = false;
        _statusText = '服務操作失敗: $e';
      });
    }
  }

  Future<void> _checkLocalhost8080() async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/'))
          .timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      if (!mounted) return;
      final healthy = response.statusCode < 500;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(healthy ? '後端服務正常，可以連線' : '後端服務回應異常，請稍後再試'),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('後端服務無回應，請確認服務是否已啟動')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法連線至後端服務，請確認服務是否已啟動')),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _requestBatteryUnrestricted() async {
    if (!Platform.isAndroid) return;
    final granted = await FlutterForegroundTask
        .requestIgnoreBatteryOptimization();

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
      appBar: AppBar(title: const Text('Bilirec 後臺服務控制中心')),
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
                                      duration: const Duration(
                                          milliseconds: 280),
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
                                                const Text(
                                                  '啟動中...',
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
                                                  _isServiceRunning),
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
                                                      ? '停止'
                                                      : '啟動',
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
                    Row(
                      children: [
                        Icon(Icons.shield, color: statusColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_statusText)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _checkLocalhost8080,
                        icon: const Icon(Icons.lan, size: 16),
                         label: const Text('檢測後端連線'),
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
                              '設置檔案輸出路徑',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _browseBasePath,
                                icon: const Icon(Icons.folder_open),
                                label: const Text('瀏覽並設置路徑'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _basePathController.text.trim().isEmpty
                                  ? '目前尚未設置路徑'
                                  : '目前路徑: ${_basePathController.text.trim()}',
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







