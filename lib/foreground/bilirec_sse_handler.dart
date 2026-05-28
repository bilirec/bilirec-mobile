import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/debugger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationChannel sseEventChannel = AndroidNotificationChannel(
  'bilirec_sse_event',
  'Bilirec SSE 推送',
  description: 'Bilirec 直播事件推送提醒',
  importance: Importance.high,
);

String generateSseToken() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(24, (_) => random.nextInt(256)),
  );
  return base64UrlEncode(bytes).replaceAll('=', '');
}

class BilirecSseEvent {
  const BilirecSseEvent({
    required this.type,
    required this.roomId,
    required this.streamer,
    required this.roomTitle,
    required this.message,
    required this.timestamp,
  });

  final String type;
  final int roomId;
  final String streamer;
  final String roomTitle;
  final String message;
  final int timestamp;

  factory BilirecSseEvent.fromJson(Map<String, dynamic> map) {
    return BilirecSseEvent(
      type: map['type']?.toString() ?? 'live_detected',
      roomId: _toInt(map['room_id']),
      streamer: map['streamer_name']?.toString() ?? '',
      roomTitle: map['room_title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      timestamp: _toInt(map['timestamp']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BilirecSseHandler {
  BilirecSseHandler({
    required this.notifications,
    required this.canRun,
    required this.l10n,
  });

  final FlutterLocalNotificationsPlugin notifications;
  final bool Function() canRun;
  final AppLocalizations l10n;

  bool _notificationsReady = false;
  String? _token;
  int _notificationId = 4000;
  HttpClient? _client;
  StreamSubscription<String>? _lineSubscription;
  Timer? _reconnectTimer;
  final StringBuffer _dataBuffer = StringBuffer();

  Future<void> start(String token) async {
    _token = token;
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(sseEventChannel);
    await _ensureNotificationReady();
    await _connect();
  }

  Future<void> stop() async {
    _token = null;
    await _closeConnection();
  }

  Future<void> _closeConnection() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _lineSubscription?.cancel();
    _lineSubscription = null;
    _client?.close(force: true);
    _client = null;
    _dataBuffer.clear();
  }

  Future<void> _ensureNotificationReady() async {
    if (_notificationsReady) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(
      const InitializationSettings(android: androidInit),
    );
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(sseEventChannel);
    _notificationsReady = true;
  }

  Future<void> _connect() async {
    if (!canRun() || _token == null) return;

    await _closeConnection();

    final client = HttpClient();
    _client = client;

    try {
      final uri = Uri.parse(
        'http://127.0.0.1:8080/notify/sse?token=${Uri.encodeQueryComponent(_token!)}',
      );
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');

      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _scheduleReconnect();
        return;
      }

      _lineSubscription =
          res.transform(utf8.decoder).transform(const LineSplitter()).listen(
        _onLine,
        onError: (e) {
          debugLog('SSE 連線錯誤: $e');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (e) {
      debugLog('SSE 連線錯誤: $e');
      _scheduleReconnect();
    }
  }

  void _onLine(String line) {
    if (line.isEmpty) {
      final payload = _dataBuffer.toString().trim();
      _dataBuffer.clear();
      if (payload.isNotEmpty) {
        _handlePayload(payload);
      }
      return;
    }

    if (line.startsWith('data:')) {
      final data = line.substring(5).trimLeft();
      debugLog('接收 SSE 資料: $data');
      if (_dataBuffer.isNotEmpty) {
        _dataBuffer.write('\n');
      }
      _dataBuffer.write(data);
    }
  }

  void _scheduleReconnect() {
    if (!canRun() || _token == null) return;
    debugLog('SSE 連線中斷，5 秒後嘗試重新連線');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      const Duration(seconds: 3),
      () => unawaited(_connect()),
    );
  }

  Future<void> _handlePayload(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final event = BilirecSseEvent.fromJson(decoded);
      await _showNotification(event);
    } catch (_) {
      // Ignore malformed SSE payloads and keep stream alive.
    }
  }

  Future<void> _showNotification(BilirecSseEvent event) async {
    await _ensureNotificationReady();

    final titleKey = switch (event.type) {
      'live_auto_record_started' => 'sseTitleAutoRecord',
      'live_auto_record_failed' => 'sseTitleAutoRecordFailed',
      'live_ended' => 'sseTitleLiveEnded',
      'live_record_stopped' => 'sseTitleRecordStopped',
      'live_detected' => 'sseTitleLive',
      _ => 'sseUnknownEvent',
    };

    final title = l10n.tr(titleKey, params: {
      'streamer': event.streamer.isNotEmpty
          ? event.streamer
          : l10n.tr('sseDefaultStreamer'),
    });

    final body = _buildBody(event);
    final tag = event.roomId > 0
        ? 'room-${event.roomId}-${event.type}'
        : 'bilirec-${event.type}';

    await notifications.show(
      _notificationId++,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          sseEventChannel.id,
          sseEventChannel.name,
          channelDescription: sseEventChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
        ),
      ),
    );

    debugLog('顯示通知: $title - $body (tag: $tag)');
  }

  String _buildBody(BilirecSseEvent event) {
    final noTitleTypes = {'live_ended', 'live_record_stopped'};
    if (!noTitleTypes.contains(event.type) &&
        event.roomTitle.trim().isNotEmpty) {
      return _truncate(_singleLine(event.roomTitle.trim()), 60);
    }

    if (event.timestamp > 0) {
      final time =
          DateTime.fromMillisecondsSinceEpoch(event.timestamp * 1000).toLocal();
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return l10n.tr('sseAtTime', params: {'time': '$hour:$minute'});
    }

    if (event.message.trim().isNotEmpty) {
      return _truncate(_singleLine(event.message.trim()), 80);
    }

    return l10n.tr('sseBodyDefault');
  }

  String _singleLine(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 1)}...';
  }
}
