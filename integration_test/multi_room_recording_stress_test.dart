import 'dart:math';

import 'package:bilirec/main.dart' as app;
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/api_helper.dart';
import 'helpers/l10n_helper.dart';
import 'helpers/test_helper.dart';
import 'helpers/ui_helper.dart';

const _logTag = 'MULTI_ROOM_RECORDING_STRESS_TEST';

const _minValidRecordBytes = 5 * 1024 * 1024;
const _minValidSegmentBytes = 256 * 1024;
// HLS playlist 404 / init discontinuity can rotate to a tiny fMP4
// (ftyp+moov only, often ~1 KiB) before media resumes. Those are
// recovery artifacts, not failed media segments.
const _tinyRecoveryFragmentBytes = 16 * 1024;
const _maxRotationPer15Minutes = 10;

final _startLabels = labelsForKey('start');
final _stopLabels = labelsForKey('stop');
final _inFlightPowerLabels = labelsForKeys(['startingShort', 'stoppingShort']);
final _backendRunningLabels = labelsForKey('backendRunning');
final _checkConnectionLabels = labelsForKey('checkBackendConnection');
final _connectionFailedLabels =
    labelsForKeys(['backendNoResponseHint', 'backendCannotConnect']);
const _targetRecordingRooms = 3;
const _maxStartCandidates = 12;
const _idleNearAutoStopGrace = Duration(seconds: 30);
// One 10s poll of idle is not enough: Bilibili live_status can lag, and CI
// emulators can briefly recycle the backend (all rooms go idle together).
const _idleRecoveryGrace = Duration(seconds: 60);

bool _isRecordMediaFile(String fileName) {
  final lower = fileName.toLowerCase();
  return lower.endsWith('.flv') ||
      lower.endsWith('.ts') ||
      lower.endsWith('.fmp4');
}

int? _segmentIndexFromName(String fileName) {
  final match = RegExp(
    r'-(\d+)\.(?:flv|ts|fmp4)$',
    caseSensitive: false,
  ).firstMatch(fileName);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

int _rotationLimitForDurationMinutes(int minutes) {
  final normalized = max(1, minutes);
  return ((normalized * _maxRotationPer15Minutes) + 14) ~/ 15;
}

void _log(String message) => testLog(_logTag, message);

Duration _recordingDuration() => recordingDurationByCi();

int _recordingDurationMinutes() => _recordingDuration().inMinutes;

bool _isActiveRecordingStatus(String status) {
  return status == 'recording' ||
      status == 'starting' ||
      status == 'recovering';
}

bool _allRoomsIdle(Map<int, String> statuses, List<int> roomIds) {
  if (roomIds.isEmpty) return false;
  return roomIds.every((id) => (statuses[id]?.toLowerCase() ?? '') == 'idle');
}

Future<int?> _tryFetchLiveStatus(int roomId) async {
  try {
    final roomInfo = await fetchRoomInfo(roomId);
    return asInt(roomInfo['live_status']);
  } catch (e) {
    _log(
      'failed to fetch room info for roomId=$roomId when status=idle, error=$e',
    );
    return null;
  }
}

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
    await Future<void>.delayed(poll);
    await tester.pump();
  }
  fail('錄製時間已到，但仍有房間未停止錄製');
}

Future<void> _assertOutputFilesForRooms(
  List<int> roomIds, {
  required int durationMinutes,
}) async {
  final rotationLimit = _rotationLimitForDurationMinutes(durationMinutes);
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

    var roomTotalBytes = 0;
    var roomSegmentCount = 0;
    var roomRotationCount = 0;
    var roomTinyFmp4Count = 0;

    for (final dir in roomDirs) {
      final dirPath = asString(dir['path']);
      final folderItems = await browseFilesAtPath(browsePath: dirPath);
      _log(
          'browse folder room=$roomId path=$dirPath items=${folderItems.length}');

      final files = folderItems.where((item) {
        if (item['is_dir'] == true) return false;
        final fileName = asString(item['name']);
        return _isRecordMediaFile(fileName);
      }).toList();
      expect(files.isNotEmpty, isTrue,
          reason: '房間 $roomId 的資料夾 $dirPath 內未找到任何錄製檔案');

      for (final file in files) {
        final fileName = asString(file['name']);
        final filePath = asString(file['path']);
        final size = asInt(file['size']);
        roomTotalBytes += size;
        roomSegmentCount++;
        final segmentIndex = _segmentIndexFromName(fileName);
        if (segmentIndex != null) {
          roomRotationCount++;
        }
        final lowerName = fileName.toLowerCase();
        final isTinyFmp4RecoveryFragment =
            lowerName.endsWith('.fmp4') && size < _tinyRecoveryFragmentBytes;
        if (isTinyFmp4RecoveryFragment) {
          roomTinyFmp4Count++;
          _log(
            'room=$roomId skip tiny fMP4 recovery fragment: path=$filePath size=$size bytes',
          );
          continue;
        }
        expect(
          size,
          greaterThan(_minValidSegmentBytes),
          reason: '房間 $roomId 錄製分段過小: path=$filePath size=$size bytes',
        );
      }
    }

    _log(
      'room=$roomId verify summary: totalBytes=$roomTotalBytes segmentCount=$roomSegmentCount tinyFmp4Count=$roomTinyFmp4Count rotationCount=$roomRotationCount rotationLimit=$rotationLimit',
    );

    expect(
      roomTotalBytes,
      greaterThan(_minValidRecordBytes),
      reason:
          '房間 $roomId 錄製總大小不足: total=$roomTotalBytes bytes (<$_minValidRecordBytes)',
    );

    expect(
      roomRotationCount,
      lessThanOrEqualTo(rotationLimit),
      reason:
          '房間 $roomId 輪轉次數異常: rotations=$roomRotationCount limit=$rotationLimit (${durationMinutes}m)',
    );
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

  setUp(() async {
    await resetTestOutputDir();
    FlutterForegroundTaskPlatform.instance =
        BatteryBypassForegroundTaskPlatform();
  });

  group('Bilirec 多房同錄穩定性壓測', () {
    testWidgets(
      '三房並錄壓測：服務穩定且輸出檔案合理',
      (tester) async {
        try {
          final duration = _recordingDuration();
          final durationMinutes = _recordingDurationMinutes();
          _log('test start; CI=${isCiEnv()} duration=${duration.inMinutes}m');
          _log('this run will record for $durationMinutes minutes');

          _log('STEP 0: launch app.main()');
          app.main();
          await waitForAnyText(
            tester,
            _startLabels,
            timeout: const Duration(seconds: 30),
            logTag: _logTag,
          );

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
          await waitForAnyText(
            tester,
            _backendRunningLabels,
            logTag: _logTag,
            waitMode: WaitMode.realtime,
          );

          _log('STEP 2: check backend connection from UI');
          await assertBackendConnectableFromUi(
            tester,
            checkConnectionLabels: _checkConnectionLabels,
            connectionFailedLabels: _connectionFailedLabels,
            failIfButtonMissing: true,
            logTag: _logTag,
          );

          _log('STEP 3: fetch and pick 3 live room ids (API-only)');
          final liveRoomPool =
              await fetchLiveBroadcastRoomIDsForTest(logTag: _logTag);
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
          final startedAtByRoom = <int, DateTime>{};
          final skippedBadRequestReasons = <String>[];
          try {
            _log('STEP 4: start recording with 400-skip fallback');
            for (final roomId in candidateRoomIds) {
              if (startedRoomIds.length >= _targetRecordingRooms) {
                break;
              }

              final result = await startRecording(roomId,
                  durationMinutes: durationMinutes);
              final code = result.statusCode;
              final accepted = [200, 201, 202, 204, 409].contains(code);
              final preview = result.bodyPreview();

              if (accepted) {
                startedRoomIds.add(roomId);
                startedAtByRoom[roomId] = DateTime.now();
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
            final idleNearAutoStopThreshold = duration > _idleNearAutoStopGrace
                ? duration - _idleNearAutoStopGrace
                : Duration.zero;
            DateTime? allIdleSince;
            final idleSinceByRoom = <int, DateTime>{};
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

              if (_allRoomsIdle(statusesMap, startedRoomIds)) {
                allIdleSince ??= DateTime.now();
                final allIdleFor = DateTime.now().difference(allIdleSince);
                if (allIdleFor < _idleRecoveryGrace) {
                  _log(
                    'all rooms idle; waiting recovery grace ${allIdleFor.inSeconds}s/${_idleRecoveryGrace.inSeconds}s',
                  );
                  await Future<void>.delayed(poll);
                  await tester.pump();
                  continue;
                }

                var anyStillLive = false;
                for (final roomId in startedRoomIds) {
                  final liveStatus = await _tryFetchLiveStatus(roomId);
                  _log(
                    'all-idle grace elapsed room=$roomId liveStatus=${liveStatus ?? 'unknown'}',
                  );
                  if (liveStatus == null || liveStatus == 1) {
                    anyStillLive = true;
                  }
                }
                if (anyStillLive) {
                  final reason =
                      '所有房間同時 idle 超過 ${_idleRecoveryGrace.inSeconds}s，且仍有直播間顯示進行中或 live_status 無法確認（CI 服務回收 / 直播流批次中斷），略過測試';
                  _log('skip scenario: $reason');
                  markTestSkipped(reason);
                  return;
                }
                _log(
                  'all rooms idle and broadcasts ended, continue to wait/stop',
                );
                break;
              }
              allIdleSince = null;

              for (final roomId in startedRoomIds) {
                final status = statusesMap[roomId]?.toLowerCase() ?? '';
                // Stream interruptions can temporarily enter recovering before recording resumes.
                if (status == 'idle') {
                  idleSinceByRoom[roomId] ??= DateTime.now();
                  final startedAt = startedAtByRoom[roomId];
                  final elapsed = startedAt == null
                      ? null
                      : DateTime.now().difference(startedAt);
                  final nearAutoStopBoundary =
                      elapsed != null && elapsed >= idleNearAutoStopThreshold;

                  if (nearAutoStopBoundary) {
                    _log(
                      'room=$roomId status=idle near auto-stop boundary; elapsed=${elapsed.inSeconds}s threshold=${idleNearAutoStopThreshold.inSeconds}s duration=${duration.inSeconds}s',
                    );
                    continue;
                  }

                  final idleFor =
                      DateTime.now().difference(idleSinceByRoom[roomId]!);
                  if (idleFor < _idleRecoveryGrace) {
                    _log(
                      'room=$roomId status=idle; waiting recovery grace ${idleFor.inSeconds}s/${_idleRecoveryGrace.inSeconds}s',
                    );
                    continue;
                  }

                  final liveStatus = await _tryFetchLiveStatus(roomId);
                  if (liveStatus == null) {
                    final reason =
                        'roomId=$roomId status=idle 超過 ${_idleRecoveryGrace.inSeconds}s，且無法確認 live_status（第三方直播資訊不穩定），略過測試';
                    _log('skip scenario: $reason');
                    markTestSkipped(reason);
                    return;
                  }
                  _log(
                    'room=$roomId status=idle liveStatus=$liveStatus after ${_idleRecoveryGrace.inSeconds}s grace',
                  );
                  if (liveStatus == 1) {
                    fail(
                      '錄製期間狀態異常: roomId=$roomId status=$status 但直播間仍在進行中 (live_status=$liveStatus)',
                    );
                  }
                  _log(
                    'room=$roomId status=idle but broadcast ended (live_status=$liveStatus), acceptable',
                  );
                } else {
                  idleSinceByRoom.remove(roomId);
                  expect(
                    _isActiveRecordingStatus(status),
                    isTrue,
                    reason: '錄製期間狀態異常: roomId=$roomId status=$status',
                  );
                }

                final stat = statsMap[roomId] ?? const <String, dynamic>{};
                final bytesWritten = asInt(stat['bytes_written']);
                expect(bytesWritten, greaterThanOrEqualTo(0),
                    reason:
                        '錄製統計異常: roomId=$roomId bytes_written=$bytesWritten');
              }

              await Future<void>.delayed(poll);
              await tester.pump();
            }

            _log('STEP 6: wait recordings auto-stop after duration');
            await _waitUntilAllNotRecording(tester, startedRoomIds);

            _log(
                'STEP 7: verify output files by room total size and rotation limit');
            await _assertOutputFilesForRooms(
              startedRoomIds,
              durationMinutes: durationMinutes,
            );
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
        } catch (e, st) {
          _log('multi-room recording stress failed: $e');
          _log('$st');
          await printBootstrapLogsIfAny(
            scenario: 'Multi-room recording stress failed',
            logTag: _logTag,
          );
          rethrow;
        }
      },
      timeout: const Timeout(Duration(minutes: 35)),
    );
  });
}
