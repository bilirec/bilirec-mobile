import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import 'bilirec_service.dart';
import 'bilirec_sse_handler.dart';
import 'resource_monitor.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _ppkAlertChannel = AndroidNotificationChannel(
  'bilirec_ppk_alert',
  'Bilirec 重要提醒',
  description: '當服務被系統中斷時顯示提醒',
  importance: Importance.high,
);

class BilirecTaskHandler extends TaskHandler {
  late final ResourceMonitor _monitor;
  late final BilirecSseHandler _sseHandler;
  late final AppLocalizations _l10n;

  bool _nativeStarted = false;
  bool _backendWasAlive = false;
  bool _sseEnabled = false;
  bool _destroyed = false;
  String? _sseToken;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    _destroyed = false;

    final appSupport = await getApplicationSupportDirectory();
    final basePath = appSupport.path;
    String? outputDir;
    try {
      final saved = await Preferences.getOutputDir() ?? '';
      outputDir = saved.isNotEmpty ? saved : null;
      _sseEnabled = await Preferences.getEnableSsePush();
      _sseToken = _sseEnabled ? generateSseToken() : null;
      await Preferences.setStoppedByUser(false);
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit),
    );

    _l10n = await _initLocalizations();
    _monitor = ResourceMonitor();
    _sseHandler = BilirecSseHandler(
      notifications: _localNotifications,
      canRun: () => !_destroyed && _nativeStarted && _sseEnabled,
      l10n: _l10n,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_ppkAlertChannel);

    BilirecService.initialize();
    final result = BilirecService.start(
      StartConfig(
        basePath: basePath,
        outputDir: outputDir,
        sseToken: _sseToken,
      ),
    );

    _nativeStarted = result == 0;
    _backendWasAlive = _nativeStarted;

    if (_nativeStarted && _sseEnabled && _sseToken != null) {
      unawaited(_sseHandler.start(_sseToken!));
    }

    FlutterForegroundTask.sendDataToMain({
      'type': 'service_started',
      'ok': _nativeStarted,
      'result': result,
    });
    await FlutterForegroundTask.saveData(
        key: coreRunningKey, value: _nativeStarted);
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    if (_nativeStarted) {
      final alive = await _pingBackend();
      if (!alive && _backendWasAlive) {
        _backendWasAlive = false;
        FlutterForegroundTask.sendDataToMain({
          'type': 'backend_dead',
          'stoppedByUser': await Preferences.getStoppedByUser(),
        });
        await _notifyPpkKilled();
        await FlutterForegroundTask.saveData(key: coreRunningKey, value: false);
      } else if (alive && !_backendWasAlive) {
        _backendWasAlive = true;
      }
    }

    final (cpu, ram) = _monitor.getUsage();
    debugPrint(
        '資源使用 - CPU: ${cpu.toStringAsFixed(2)}%, RAM: ${ram.toStringAsFixed(2)}MB');
    final text = _l10n.tr('notificationTextRunning');
    final recordingLabel = _l10n.tr('recording');
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

  Future<void> _notifyPpkKilled() async {
    await Preferences.setExpectedRunning(false);
    await _localNotifications.show(
      2027,
      _l10n.tr('ppkKilledTitle'),
      _l10n.tr('ppkKilledBody'),
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

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    final opId = DateTime.now().microsecondsSinceEpoch;
    final sw = Stopwatch()..start();
    debugPrint('[STOP/TASK][$opId] onDestroy enter (isTimeout=$isTimeout)');
    _destroyed = true;
    debugPrint('[STOP/TASK][$opId] before _sseHandler.stop()');
    await _sseHandler.stop();
    debugPrint(
        '[STOP/TASK][$opId] after _sseHandler.stop() (${sw.elapsedMilliseconds}ms)');
    if (_nativeStarted) {
      debugPrint('[STOP/TASK][$opId] before BilirecService.stop()');
      BilirecService.stop();
      _nativeStarted = false;
      debugPrint(
          '[STOP/TASK][$opId] after BilirecService.stop() (${sw.elapsedMilliseconds}ms)');
    }
    debugPrint('[STOP/TASK][$opId] before Preferences.getStoppedByUser()');
    final stoppedByUser = await Preferences.getStoppedByUser();
    debugPrint(
        '[STOP/TASK][$opId] after Preferences.getStoppedByUser() (${sw.elapsedMilliseconds}ms) value=$stoppedByUser');
    debugPrint('[STOP/TASK][$opId] before sendDataToMain(service_stopped)');
    FlutterForegroundTask.sendDataToMain({
      'type': 'service_stopped',
      'stoppedByUser': stoppedByUser,
    });
    debugPrint(
        '[STOP/TASK][$opId] after sendDataToMain(service_stopped) (${sw.elapsedMilliseconds}ms)');
    debugPrint('[STOP/TASK][$opId] before saveData(core_running=false)');
    await FlutterForegroundTask.saveData(key: coreRunningKey, value: false);
    debugPrint(
        '[STOP/TASK][$opId] onDestroy exit (${sw.elapsedMilliseconds}ms)');
  }

  @override
  void onReceiveData(Object data) {}

  Future<AppLocalizations> _initLocalizations() async {
    final locale = await Preferences.getLocaleCode();
    final code = AppLocaleConfig.codeForLocale(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    return AppLocalizations(AppLocaleConfig.localeForCode(locale ?? code));
  }

  @override
  void onNotificationButtonPressed(String id) async {
    // Handle critical notification actions in task isolate so they still work
    // after the UI process is swiped away.
    if (id == 'stop') {
      final opId = DateTime.now().microsecondsSinceEpoch;
      final sw = Stopwatch()..start();
      debugPrint('[STOP/NOTI][$opId] stop button pressed');
      debugPrint('[STOP/NOTI][$opId] before setStoppedByUser(true)');
      await Preferences.setStoppedByUser(true);
      debugPrint(
          '[STOP/NOTI][$opId] after setStoppedByUser(true) (${sw.elapsedMilliseconds}ms)');
      debugPrint('[STOP/NOTI][$opId] before setExpectedRunning(false)');
      await Preferences.setExpectedRunning(false);
      debugPrint(
          '[STOP/NOTI][$opId] after setExpectedRunning(false) (${sw.elapsedMilliseconds}ms)');

      if (_nativeStarted) {
        debugPrint('[STOP/NOTI][$opId] before BilirecService.stop()');
        BilirecService.stop();
        _nativeStarted = false;
        debugPrint(
            '[STOP/NOTI][$opId] after BilirecService.stop() (${sw.elapsedMilliseconds}ms)');
      }

      debugPrint('[STOP/NOTI][$opId] before FlutterForegroundTask.stopService()');
      await FlutterForegroundTask.stopService();
      debugPrint(
          '[STOP/NOTI][$opId] after FlutterForegroundTask.stopService() (${sw.elapsedMilliseconds}ms)');
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/');
}
