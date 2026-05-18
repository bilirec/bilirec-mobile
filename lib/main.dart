import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bilirec_service.dart';

const String _expectedRunningKey = 'expected_service_running';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BilirecTaskHandler());
}

class BilirecTaskHandler extends TaskHandler {
  bool _nativeStarted = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    BilirecService.initialize();
    final result = BilirecService.start();
    _nativeStarted = result == 0;

    FlutterForegroundTask.sendDataToMain({
      'type': 'service_started',
      'ok': _nativeStarted,
      'result': result,
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'heartbeat',
      'time': timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    var result = 0;
    if (_nativeStarted) {
      result = BilirecService.stop();
      _nativeStarted = false;
    }

    FlutterForegroundTask.sendDataToMain({
      'type': 'service_stopped',
      'isTimeout': isTimeout,
      'result': result,
    });
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['action'] == 'ping') {
      FlutterForegroundTask.sendDataToMain({
        'type': 'action_ack',
        'source': 'ui',
        'time': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'action_ack',
      'source': 'notification',
      'id': id,
      'time': DateTime.now().toIso8601String(),
    });
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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

class _BilirecHomePageState extends State<BilirecHomePage> {
  bool _isServiceRunning = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _loading = true;
  String _statusText = '初始化中...';

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _bootstrap();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final expectedRunning = prefs.getBool(_expectedRunningKey) ?? false;
    final running = await FlutterForegroundTask.isRunningService;
    final ignoringOptimization = Platform.isAndroid
        ? await FlutterForegroundTask.isIgnoringBatteryOptimizations
        : true;

    var status = running ? 'Bilirec 後端運行中' : 'Bilirec 後端未運行';
    if (expectedRunning && !running) {
      status = '偵測到服務中斷，可能被省電機制關閉（PPK）';
    }

    if (!mounted) return;
    setState(() {
      _isServiceRunning = running;
      _isIgnoringBatteryOptimizations = ignoringOptimization;
      _statusText = status;
      _loading = false;
    });
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;

    final type = data['type']?.toString();
    if (!mounted) return;

    switch (type) {
      case 'service_started':
        final ok = data['ok'] == true;
        setState(() {
          _isServiceRunning = ok;
          _statusText = ok
              ? 'Bilirec 後端運行中'
              : '服務啟動失敗，代碼: ${data['result']}';
        });
        break;
      case 'service_stopped':
        setState(() {
          _isServiceRunning = false;
          _statusText = 'Bilirec 後端已停止';
        });
        break;
      case 'action_ack':
        final source = data['source']?.toString() ?? 'unknown';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('服務已收到通知（來源: $source）')),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _setExpectedRunning(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expectedRunningKey, value);
  }

  Future<void> _toggleService(bool enable) async {
    setState(() {
      _loading = true;
    });

    if (!Platform.isAndroid) {
      setState(() {
        _statusText = '目前僅支援 Android 前景服務';
        _loading = false;
      });
      return;
    }

    try {
      if (enable) {
        final permission = await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          final requested = await FlutterForegroundTask.requestNotificationPermission();
          if (requested != NotificationPermission.granted) {
            setState(() {
              _statusText = '通知權限未開啟，無法啟動前景服務';
            });
            return;
          }
        }

        final started = await FlutterForegroundTask.startService(
          serviceId: 2026,
          notificationTitle: 'Bilirec 後端正在運行',
          notificationText: '點選按鈕可通知服務，避免被系統回收',
          notificationButtons: [
            const NotificationButton(id: 'notify', text: '通知服務'),
          ],
          callback: startCallback,
        );
        final ok = started is ServiceRequestSuccess;

        await _setExpectedRunning(ok);
        setState(() {
          _isServiceRunning = ok;
          _statusText = ok ? 'Bilirec 後端運行中' : '前景服務啟動失敗';
        });
      } else {
        final stopped = await FlutterForegroundTask.stopService();
        final ok = stopped is ServiceRequestSuccess;
        await _setExpectedRunning(false);
        setState(() {
          _isServiceRunning = !ok;
          _statusText = ok ? 'Bilirec 後端已停止' : '停止服務失敗';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = '服務操作失敗: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _notifyService() async {
    FlutterForegroundTask.sendDataToTask({'action': 'ping'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已送出通知給服務')),
    );
  }

  Future<void> _requestBatteryUnrestricted() async {
    if (!Platform.isAndroid) return;
    final granted = await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    if (!granted) {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    }

    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;
    setState(() {
      _isIgnoringBatteryOptimizations = ignoring;
      if (ignoring) {
        _statusText = '已設定電池無限制，bilirec 更不容易被系統終止';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isServiceRunning ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(title: const Text('Bilirec 控制中心')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: statusColor, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isServiceRunning ? '已啟用' : '未啟用',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(_statusText),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _isServiceRunning,
                          onChanged: (v) => _toggleService(v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isServiceRunning ? _notifyService : null,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('通知服務（前景通知按鈕同功能）'),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '電池優化設定',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isIgnoringBatteryOptimizations
                              ? '目前狀態: 已無限制'
                              : '目前狀態: 仍可能受系統省電策略影響（PPK）',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _requestBatteryUnrestricted,
                          icon: const Icon(Icons.battery_saver),
                          label: const Text('引導設定為電池無限制'),
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
