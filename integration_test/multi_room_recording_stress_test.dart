import 'dart:math';

import 'package:bilirec/main.dart' as app;
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/api_helper.dart';
import 'helpers/test_helper.dart';
import 'helpers/ui_helper.dart';

const _logTag = 'MULTI_ROOM_RECORDING_STRESS_TEST';

const _minValidRecordBytes = 5 * 1024 * 1024;

const _startLabels = ['啟動', '启动'];
const _stopLabels = ['停止'];
const _inFlightPowerLabels = ['啟動中', '启动中', '停止中'];
const _backendRunningLabels = [
  'Bilirec 系統服務運行中',
  'Bilirec 系统服务运行中',
  'Bilirec 後端運行中',
];
const _checkConnectionLabels = ['檢查系統服務連線', '检查系统服务连接', '檢測後端連線'];
const _connectionFailedLabels = [
  'Bilirec 系統服務沒有回應，請確認已啟動',
  'Bilirec 系统服务没有响应，请确认已启动',
  '目前無法連線到 Bilirec 系統服務，請確認已啟動',
  '目前无法连接到 Bilirec 系统服务，请确认已启动',
];
const _targetRecordingRooms = 3;
const _maxStartCandidates = 12;

void _log(String message) => testLog(_logTag, message);

Duration _recordingDuration() => recordingDurationByCi();

int _recordingDurationMinutes() => _recordingDuration().inMinutes;

Future<void> _waitUntilAllNotRecording(
  WidgetTester tester,
  List<int> roomIds, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final poll = const Duration(seconds: 10);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;
  for (var i = 0; i < rounds; i++) {
    final statuses = await fetchRecordStatuses(roomIds);
    _log('wait stop poll=${i + 1}/$rounds statuses=$statuses');
    final allStopped = roomIds.every((id) {
      final status = statuses[id]?.toLowerCase() ?? '';
      return status != 'recording' && status != 'starting';
    });
    if (allStopped) {
      return;
    }
    await tester.pump(poll);
  }
  fail('錄製時間已到，但仍有房間未停止錄製');
}

Future<void> _assertOutputFilesForRooms(List<int> roomIds) async {
  for (final roomId in roomIds) {
    final rootItems = await browseFiles(search: roomId.toString());
    _log('browse root room=$roomId items=${rootItems.length}');

    final visibleDirs = rootItems
        .where((item) => item['is_dir'] == true)
        .map((item) => asString(item['path']))
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    final roomDirs = rootItems.where((item) {
      final isDir = item['is_dir'] == true;
      if (!isDir) return false;
      final name = asString(item['name']);
      final path = asString(item['path']);
      return name.contains('$roomId') || path.contains('$roomId');
    }).toList();

    if (roomDirs.isEmpty) {
      _log('room folder not found for room=$roomId, visibleDirs=$visibleDirs');
    }

    expect(roomDirs.isNotEmpty, isTrue,
        reason: '房間 $roomId 未找到包含直播間 ID 的輸出資料夾');

    for (final dir in roomDirs) {
      final dirPath = asString(dir['path']);
      final folderItems = await browseFilesAtPath(browsePath: dirPath);
      _log(
          'browse folder room=$roomId path=$dirPath items=${folderItems.length}');

      final files =
          folderItems.where((item) => item['is_dir'] != true).toList();
      expect(files.isNotEmpty, isTrue,
          reason: '房間 $roomId 的資料夾 $dirPath 內未找到任何錄製檔案');

      for (final file in files) {
        final filePath = asString(file['path']);
        final size = asInt(file['size']);
        expect(
          size,
          greaterThan(_minValidRecordBytes),
          reason: '房間 $roomId 錄製檔過小: path=$filePath size=$size bytes',
        );
      }
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterForegroundTaskPlatform originalPlatform;

  setUpAll(() {
    originalPlatform = FlutterForegroundTaskPlatform.instance;
    FlutterForegroundTaskPlatform.instance =
        BatteryBypassForegroundTaskPlatform();
  });

  tearDownAll(() {
    FlutterForegroundTaskPlatform.instance = originalPlatform;
  });

  setUp(() {
    FlutterForegroundTaskPlatform.instance =
        BatteryBypassForegroundTaskPlatform();
  });

  group('Bilirec 多房同錄穩定性壓測', () {
    testWidgets(
      '三房並錄壓測：服務穩定且輸出檔案合理',
      (tester) async {
        final duration = _recordingDuration();
        final durationMinutes = _recordingDurationMinutes();
        _log('test start; CI=${isCiEnv()} duration=${duration.inMinutes}m');
        _log('this run will record for $durationMinutes minutes');

        _log('STEP 0: launch app.main()');
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        _log('STEP 0.5: ensure notification permission');
        await ensureForegroundNotificationPermissionGranted(logTag: _logTag);

        _log('STEP 1: start service');
        await tapPowerButton(
          tester,
          startLabels: _startLabels,
          stopLabels: _stopLabels,
          logTag: _logTag,
        );
        await tester.pump(const Duration(milliseconds: 500));
        await waitForAnyText(tester, _backendRunningLabels, logTag: _logTag);

        _log('STEP 2: check backend connection from UI');
        await assertBackendConnectableFromUi(
          tester,
          checkConnectionLabels: _checkConnectionLabels,
          connectionFailedLabels: _connectionFailedLabels,
          failIfButtonMissing: true,
          logTag: _logTag,
        );

        _log('STEP 3: fetch and pick 3 live room ids (API-only)');
        final liveRoomPool = await fetchLiveBroadcastRoomIDs();
        if (liveRoomPool.length < _targetRecordingRooms) {
          final reason =
              'broadcast API 回傳可用直播間不足 $_targetRecordingRooms 個，fetched=${liveRoomPool.length}';
          _log('skip scenario: $reason');
          markTestSkipped(reason);
          return;
        }
        final candidateCount = min(liveRoomPool.length, _maxStartCandidates);
        final candidateRoomIds =
            pickDistinctRoomIDs(liveRoomPool, candidateCount);
        _log('picked candidate room ids: $candidateRoomIds');

        final startedRoomIds = <int>[];
        final skippedBadRequestReasons = <String>[];
        try {
          _log('STEP 4: start recording with 400-skip fallback');
          for (final roomId in candidateRoomIds) {
            if (startedRoomIds.length >= _targetRecordingRooms) {
              break;
            }

            final result =
                await startRecording(roomId, durationMinutes: durationMinutes);
            final code = result.statusCode;
            final accepted = [200, 201, 202, 204, 409].contains(code);
            final preview = result.bodyPreview();

            if (accepted) {
              startedRoomIds.add(roomId);
              _log('start recording success roomId=$roomId statusCode=$code');
              continue;
            }

            if (code == 400) {
              final skipReason =
                  'roomId=$roomId statusCode=400 responseBody="$preview"';
              skippedBadRequestReasons.add(skipReason);
              _log('start recording skipped: $skipReason');
              continue;
            }

            fail(
              '開始錄製失敗（非可忽略錯誤）: roomId=$roomId, statusCode=$code, responseBody="$preview"',
            );
          }

          if (startedRoomIds.length < _targetRecordingRooms) {
            final reason =
                'unable to start $_targetRecordingRooms rooms; started=${startedRoomIds.length}, badRequestDetails=$skippedBadRequestReasons';
            _log('skip scenario: $reason');
            markTestSkipped(reason);
            return;
          }

          _log('STEP 5: monitor recording status during target duration');
          final poll = const Duration(seconds: 10);
          final rounds = duration.inMilliseconds ~/ poll.inMilliseconds;
          for (var i = 0; i < rounds; i++) {
            assertAppAlive(
              controlLabels: [
                ..._startLabels,
                ..._stopLabels,
                ..._inFlightPowerLabels
              ],
            );
            final statusesMap = await fetchRecordStatuses(startedRoomIds);
            final statsMap = await fetchRecordStats(startedRoomIds);
            _log('monitor poll=${i + 1}/$rounds statuses=$statusesMap');

            for (final roomId in startedRoomIds) {
              final status = statusesMap[roomId]?.toLowerCase() ?? '';
              // Stream interruptions can temporarily enter recovering before recording resumes.
              if (status == 'idle') {
                // If the room becomes idle, check if the broadcast actually ended
                try {
                  final roomInfo = await fetchRoomInfo(roomId);
                  final liveStatus = asInt(roomInfo['live_status']);
                  _log(
                    'room=$roomId status=idle liveStatus=$liveStatus; if liveStatus==1 then it\'s a service error',
                  );
                  // If live_status == 1, the broadcast is still live, which means this is a real error
                  expect(
                    liveStatus != 1,
                    isTrue,
                    reason:
                        '錄製期間狀態異常: roomId=$roomId status=$status 但直播間仍在進行中 (live_status=$liveStatus)',
                  );
                  _log(
                    'room=$roomId status=idle but broadcast ended (live_status=$liveStatus), acceptable',
                  );
                } catch (e) {
                  _log(
                    'failed to fetch room info for roomId=$roomId when status=idle, error=$e',
                  );
                  rethrow;
                }
              } else {
                expect(
                  ['recording', 'starting', 'recovering'].contains(status),
                  isTrue,
                  reason: '錄製期間狀態異常: roomId=$roomId status=$status',
                );
              }

              final stat = statsMap[roomId] ?? const <String, dynamic>{};
              final bytesWritten = asInt(stat['bytes_written']);
              expect(bytesWritten, greaterThanOrEqualTo(0),
                  reason: '錄製統計異常: roomId=$roomId bytes_written=$bytesWritten');
            }

            await tester.pump(poll);
          }

          _log('STEP 6: wait recordings auto-stop after duration');
          await _waitUntilAllNotRecording(tester, startedRoomIds);

          _log('STEP 7: verify output files and file size (>5MB)');
          await _assertOutputFilesForRooms(startedRoomIds);
        } finally {
          _log('FINAL STEP: stop started recordings and shutdown service');
          for (final roomId in startedRoomIds) {
            try {
              await stopRecording(roomId);
            } catch (e) {
              _log('ignore stop recording error roomId=$roomId error=$e');
            }
          }
          await shutdownServiceSafely(
            tester,
            inFlightLabels: _inFlightPowerLabels,
            startLabels: _startLabels,
            stopLabels: _stopLabels,
            logTag: _logTag,
          );
        }

        expect(
          findFirstVisibleText(_startLabels, logTag: _logTag)
              .evaluate()
              .isNotEmpty,
          isTrue,
          reason: '壓測完成後應仍存活，且服務已回到停止狀態',
        );
        _log('test done: multi-room recording stress passed');
      },
      timeout: const Timeout(Duration(minutes: 35)),
    );
  });
}
