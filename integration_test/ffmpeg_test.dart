import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';

import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/main.dart' as app;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'helpers/api_helper.dart';
import 'helpers/l10n_helper.dart';
import 'helpers/test_helper.dart';
import 'helpers/ui_helper.dart';

const _logTag = 'FFMPEG_TEST';

typedef _FfmpegExecuteNative = ffi.Int32 Function(
  ffi.Int32 argc,
  ffi.Pointer<ffi.Pointer<ffi.Char>> argv,
);
typedef _FfmpegExecuteDart = int Function(
  int argc,
  ffi.Pointer<ffi.Pointer<ffi.Char>> argv,
);

void _log(String message) => testLog(_logTag, message);

String _fileNameFromPath(String path) {
  final parts = path.split(RegExp(r'[\\/]+'));
  return parts.isEmpty ? path : parts.last;
}

String _fileStem(String path) {
  final name = _fileNameFromPath(path);
  final idx = name.lastIndexOf('.');
  if (idx <= 0) return name;
  return name.substring(0, idx);
}

String _parentPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  if (idx <= 0) return '';
  return normalized.substring(0, idx);
}

// 1. 定義原生 C 簽名 (必須包在 NativeFunction 裡面)
typedef NativeSetEnv = ffi.Int32 Function(ffi.Pointer<Utf8> name, ffi.Pointer<Utf8> value, ffi.Int32 overwrite);

// 2. 定義 Dart 端的對應簽名
typedef DartSetEnv = int Function(ffi.Pointer<Utf8> name, ffi.Pointer<Utf8> value, int overwrite);

int _executeFfmpeg(List<String> args) {
  final lib = ffi.DynamicLibrary.open('libffmpegkit.so');

  final libc = ffi.DynamicLibrary.open('libc.so');
  final setEnv = libc.lookupFunction<NativeSetEnv, DartSetEnv>('setenv');

  final name = 'FFREPORT'.toNativeUtf8();
  final value = 'file=/data/user/0/org.bilirec.bilirec/cache/ffmpeg.log:level=32'.toNativeUtf8();

  try {
    setEnv(name, value, 1);
  } finally {
    malloc.free(name);
    malloc.free(value);
  }

  final execute =
      lib.lookupFunction<_FfmpegExecuteNative, _FfmpegExecuteDart>('ffmpeg_execute');

  _log('ffmpeg execute start: argv=[${args.join(", ")}]');

  final argv = calloc<ffi.Pointer<ffi.Char>>(args.length);
  final allocatedUtf8 = <ffi.Pointer<Utf8>>[];
  try {
    for (var i = 0; i < args.length; i++) {
      final ptr = args[i].toNativeUtf8();
      allocatedUtf8.add(ptr);
      argv[i] = ptr.cast<ffi.Char>();
    }
    final exitCode = execute(args.length, argv);
    _log('ffmpeg execute done: exitCode=$exitCode');
    return exitCode;
  } finally {
    for (final ptr in allocatedUtf8) {
      calloc.free(ptr);
    }
    calloc.free(argv);

    // find report file
    final reportFile = File('/data/user/0/org.bilirec.bilirec/cache/ffmpeg.log');
    try {
      if (reportFile.existsSync()) {
        final content = reportFile.readAsStringSync();
        _log('===== FFMPEG REPORT ======\n$content\n===== END OF REPORT ======');
        reportFile.deleteSync();
      } else {
        _log('ffmpeg report file not found at expected path');
      }
    } catch (e) {
      _log('error while reading ffmpeg report file: $e');
    }
  }
}


Future<File> _downloadDemoFlv(Directory workDir) async {
  const demoUrls = <String>[
    'http://docs.evostream.com/sample_content/assets/bun33s.flv',
  ];

  final client = HttpClient();
  try {
    for (final url in demoUrls) {
      try {
        final uri = Uri.parse(url);
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
        final response = await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          _log('demo download skip: status=${response.statusCode} url=$url');
          continue;
        }

        final outFile = File('${workDir.path}${Platform.pathSeparator}demo.flv');
        final sink = outFile.openWrite();
        await response.pipe(sink);
        await sink.close();

        if (outFile.lengthSync() > 0) {
          _log('demo flv downloaded: path=${outFile.path} bytes=${outFile.lengthSync()}');
          return outFile;
        }
      } catch (e) {
        _log('demo download failed: url=$url error=$e');
      }
    }
  } finally {
    client.close(force: true);
  }

  throw StateError('無法下載 demo flv（所有候選 URL 皆失敗）');
}

Future<String?> _findRecordedFilePath(int roomId) async {
  final rootItems = await browseFiles(search: roomId.toString());
  final roomIdText = roomId.toString();
  final roomDirCandidates = rootItems.where((item) {
    if (item['is_dir'] != true) return false;
    final name = asString(item['name']);
    final path = asString(item['path']);
    return name.endsWith('-$roomIdText') || path.endsWith('-$roomIdText');
  }).toList(growable: false);

  final fileRegex = RegExp(
    r'-\d{8}_\d{6}\.(flv|ts|fmp4)$',
    caseSensitive: false,
  );
  final matched = <Map<String, dynamic>>[];

  Future<void> collectFromDir(String dirPath) async {
    final items = await browseFilesAtPath(browsePath: dirPath);
    for (final item in items) {
      if (item['is_dir'] == true) continue;
      final fileName = asString(item['name']);
      if (fileRegex.hasMatch(fileName)) {
        matched.add(item);
      }
    }
  }

  for (final dir in roomDirCandidates) {
    final dirPath = asString(dir['path']);
    if (dirPath.isEmpty) continue;
    await collectFromDir(dirPath);
  }

  if (matched.isEmpty) {
    for (final item in rootItems) {
      if (item['is_dir'] == true) continue;
      final fileName = asString(item['name']);
      final filePath = asString(item['path']);
      if (filePath.contains('-$roomIdText/') && fileRegex.hasMatch(fileName)) {
        matched.add(item);
      }
    }
  }

  if (matched.isEmpty) {
    _log('find record: room=$roomId no matched files; roomDirs=${roomDirCandidates.length}');
    return null;
  }

  matched.sort((a, b) {
    final sizeCompare = asInt(b['size']).compareTo(asInt(a['size']));
    if (sizeCompare != 0) return sizeCompare;
    return asString(b['name']).compareTo(asString(a['name']));
  });

  final picked = asString(matched.first['path']);
  _log('find record: room=$roomId pick=$picked candidates=${matched.length}');
  return picked;
}

Future<String?> _waitForRecordedFilePath(
  int roomId, {
  required Duration timeout,
}) async {
  const poll = Duration(seconds: 5);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;
  for (var i = 0; i < rounds; i++) {
    final path = await _findRecordedFilePath(roomId);
    if (path != null && path.isNotEmpty) {
      return path;
    }
    _log('find record poll=${i + 1}/$rounds room=$roomId not found yet');
    await Future<void>.delayed(poll);
  }
  return null;
}

Future<void> _waitUntilRecordingStopped(
  int roomId, {
  required Duration timeout,
}) async {
  const poll = Duration(seconds: 10);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;

  for (var i = 0; i < rounds; i++) {
    final statuses = await fetchRecordStatuses([roomId]);
    final status = (statuses[roomId] ?? '').toLowerCase();
    _log('recording poll=${i + 1}/$rounds room=$roomId status=$status');

    final finished =
        status.isEmpty || (status != 'recording' && status != 'starting' && status != 'recovering');
    if (finished) {
      return;
    }

    await Future<void>.delayed(poll);
  }

  throw StateError('錄製等待超時，roomId=$roomId');
}

Future<void> _waitUntilConvertDone({
  required String sourcePath,
  required Duration timeout,
  String? taskId,
}) async {
  const poll = Duration(seconds: 4);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;

  for (var i = 0; i < rounds; i++) {
    final tasks = await listConvertTasks();
    final hasTarget = tasks.any((task) {
      return task.inputPath == sourcePath || (taskId != null && task.taskId == taskId);
    });

    _log('convert poll=${i + 1}/$rounds queue=${tasks.length} hasTarget=$hasTarget');

    if (!hasTarget) {
      return;
    }

    await Future<void>.delayed(poll);
  }

  throw StateError('轉檔等待超時，source=$sourcePath');
}

Future<String?> _findConvertedOutputPath(String sourcePath) async {
  final dirPath = _parentPath(sourcePath);
  final stem = _fileStem(sourcePath);
  final items = await browseFilesAtPath(browsePath: dirPath);

  final candidates = items.where((item) {
    if (item['is_dir'] == true) return false;
    final name = asString(item['name']);
    final lowerName = name.toLowerCase();
    final converted =
        (lowerName.endsWith('.mp4') || lowerName.endsWith('.mkv')) && name.contains(stem);
    return converted;
  }).toList(growable: false);

  if (candidates.isEmpty) {
    return null;
  }

  candidates.sort((a, b) => asInt(b['size']).compareTo(asInt(a['size'])));
  return asString(candidates.first['path']);
}

Future<List<String>> _loadFfmpegCoreLinesFromBootstrapLog() async {
  final appSupportDir = await getApplicationSupportDirectory();
  final bootstrapLogPath =
      '${appSupportDir.path}${Platform.pathSeparator}bootstrap.log';
  final bootstrapLogFile = File(bootstrapLogPath);

  if (!await bootstrapLogFile.exists()) {
    _log('bootstrap.log not found: path=$bootstrapLogPath');
    return const <String>[];
  }

  final lines = await bootstrapLogFile.readAsLines();
  final ffmpegCoreLines = lines
      .where((line) => line.contains('component=ffmpeg_core'))
      .toList(growable: false);
  _log(
    'bootstrap.log loaded: path=$bootstrapLogPath totalLines=${lines.length} ffmpegCoreLines=${ffmpegCoreLines.length}',
  );
  return ffmpegCoreLines;
}

Future<void> _expectAndPrintNewFfmpegCoreBootstrapLogs({
  required int baselineCount,
  required String scenario,
}) async {
  final ffmpegCoreLines = await _loadFfmpegCoreLinesFromBootstrapLog();
  final start = baselineCount <= ffmpegCoreLines.length ? baselineCount : 0;
  final newLines = ffmpegCoreLines.skip(start).toList(growable: false);

  expect(
    newLines.isNotEmpty,
    isTrue,
    reason: 'bootstrap.log 缺少 component=ffmpeg_core 日誌，scenario=$scenario',
  );

  if (newLines.isEmpty) return;

  _log('===== bootstrap.log component=ffmpeg_core ($scenario) =====');
  for (final line in newLines.take(80)) {
    _log(line);
  }
  if (newLines.length > 80) {
    _log('... ${newLines.length - 80} more ffmpeg_core lines omitted ...');
  }
  _log('===== end bootstrap.log component=ffmpeg_core ($scenario) =====');
}

Future<void> _closeSettingsSheet(WidgetTester tester) async {
  await tester.fling(
    find.byType(SettingsDrawerSheet),
    const Offset(0, 700),
    1400,
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 300));

  final sheetFinder = find.byType(SettingsDrawerSheet);
  if (sheetFinder.evaluate().isNotEmpty) {
    final sheetContext = tester.element(sheetFinder.first);
    Navigator.of(sheetContext).pop();
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
}

Future<bool> _setConvertToMp4FromSettings(
  WidgetTester tester, {
  required Iterable<String> settingsLabels,
  required Iterable<String> convertToMp4Labels,
  required bool enabled,
}) async {
  await tester.tap(findFirstVisibleText(settingsLabels, logTag: _logTag).first);
  await tester.pumpAndSettle(const Duration(milliseconds: 400));

  await waitForAnyText(tester, convertToMp4Labels, logTag: _logTag);
  final labelFinder =
      findFirstVisibleText(convertToMp4Labels, logTag: _logTag).first;
  await tester.ensureVisible(labelFinder);
  await tester.pump(const Duration(milliseconds: 120));

  final tileFinder =
      find.ancestor(of: labelFinder, matching: find.byType(SwitchListTile));
  expect(tileFinder, findsWidgets, reason: '找不到自動轉 MP4 開關列');

  final switchFinder = find.descendant(
    of: tileFinder.first,
    matching: find.byType(Switch),
  );
  expect(switchFinder, findsWidgets, reason: '找不到自動轉 MP4 開關');

  final current = tester.widget<Switch>(switchFinder.first).value;
  _log('convertToMp4 current=$current target=$enabled');
  if (current != enabled) {
    await tester.tap(switchFinder.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  await _closeSettingsSheet(tester);
  return current;
}

Future<TaskQueue?> _waitForConvertTaskEnqueued({
  required String sourcePath,
  required Duration timeout,
}) async {
  const poll = Duration(seconds: 1);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;

  for (var i = 0; i < rounds; i++) {
    final tasks = await listConvertTasks();
    final matched = tasks.where((task) => task.inputPath == sourcePath).toList();
    _log(
      'convert enqueue poll=${i + 1}/$rounds queue=${tasks.length} matched=${matched.length}',
    );
    if (matched.isNotEmpty) {
      return matched.first;
    }
    await Future<void>.delayed(poll);
  }

  return null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterForegroundTaskPlatform originalPlatform;

  setUpAll(() {
    originalPlatform = FlutterForegroundTaskPlatform.instance;
    FlutterForegroundTaskPlatform.instance = BatteryBypassForegroundTaskPlatform();
  });

  tearDownAll(() {
    FlutterForegroundTaskPlatform.instance = originalPlatform;
  });

  setUp(() {
    FlutterForegroundTaskPlatform.instance = BatteryBypassForegroundTaskPlatform();
  });

  group('FFmpeg 測試', () {
    testWidgets(
      'Dynamic load + ffmpeg -version',
      (tester) async {
        final exitCode = _executeFfmpeg(<String>['ffmpeg', '-version']);
        expect(exitCode, 0, reason: 'ffmpeg -version 回傳非 0: $exitCode');
      },
      skip: !Platform.isAndroid,
    );

    testWidgets(
      '下載 demo flv 並以 -c copy 轉換',
      (tester) async {
        final workDir = await Directory.systemTemp.createTemp('ffmpeg-it-');
        try {
          late final File inputFile;
          try {
            inputFile = await _downloadDemoFlv(workDir);
          } catch (e) {
            markTestSkipped('demo 下載失敗，略過轉檔測試: $e');
            return;
          }

          final outputPath =
              '${workDir.path}${Platform.pathSeparator}demo_copy.mp4';

          final exitCode = _executeFfmpeg(<String>[
            'ffmpeg',
            '-i',
            inputFile.path,
            '-map', '0:v?',
            '-map', '0:a?',
            '-c',
            'copy',
            '-movflags',
            '+faststart',
            outputPath,
          ]);

          final outputFile = File(outputPath);
          expect(exitCode, 0, reason: 'ffmpeg copy 轉換失敗: $exitCode');
          expect(outputFile.existsSync(), isTrue, reason: '轉換輸出檔不存在');
          expect(outputFile.lengthSync(), greaterThan(0), reason: '轉換輸出檔大小為 0');
        } finally {
          if (await workDir.exists()) {
            await workDir.delete(recursive: true);
          }
        }
      },
      skip: !Platform.isAndroid,
    );

    testWidgets(
      '啟動 app 後錄製並透過 Convert API 轉檔',
      (tester) async {
        const maxStartCandidates = 12;
        final recordDurationMinutes = isCiEnv() ? 5 : 1;
        final waitRecordingTimeout =
            isCiEnv() ? const Duration(minutes: 8) : const Duration(minutes: 3);
        final waitRecordFileTimeout =
            isCiEnv() ? const Duration(minutes: 2) : const Duration(seconds: 45);
        final waitConvertTimeout =
            isCiEnv() ? const Duration(minutes: 6) : const Duration(minutes: 3);
        final startLabels = labelsForKey('start');
        final stopLabels = labelsForKey('stop');
        final inFlightPowerLabels =
            labelsForKeys(['startingShort', 'stoppingShort']);
        final backendRunningLabels = labelsForKey('backendRunning');

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await ensureForegroundNotificationPermissionGranted(logTag: _logTag);

        await tapPowerButton(
          tester,
          startLabels: startLabels,
          stopLabels: stopLabels,
          logTag: _logTag,
        );
        await waitForAnyText(tester, backendRunningLabels, logTag: _logTag);

        final liveRoomPool = await fetchLiveBroadcastRoomIDs();
        if (liveRoomPool.isEmpty) {
          markTestSkipped('broadcast API 無可用直播間，略過錄製轉檔測試');
          return;
        }

        final candidateCount = min(liveRoomPool.length, maxStartCandidates);
        final candidateRoomIds = pickDistinctRoomIDs(liveRoomPool, candidateCount);
        _log('candidates: $candidateRoomIds');

        int? selectedRoomId;
        final skippedReasons = <String>[];

        for (final roomId in candidateRoomIds) {
          final startResult =
              await startRecording(roomId, durationMinutes: recordDurationMinutes);
          final code = startResult.statusCode;
          final preview = startResult.bodyPreview();

          if ([200, 201, 202, 204, 409].contains(code)) {
            selectedRoomId = roomId;
            _log('start recording success roomId=$roomId statusCode=$code');
            break;
          }

          if (code == 400) {
            final reason = 'roomId=$roomId statusCode=400 body="$preview"';
            skippedReasons.add(reason);
            _log('skip candidate: $reason');
            continue;
          }

          fail('開始錄製失敗（非可忽略錯誤）: roomId=$roomId statusCode=$code body="$preview"');
        }

        if (selectedRoomId == null) {
          final reason =
              '所有候選直播間皆非直播狀態，skipped=$skippedReasons';
          _log('skip test: $reason');
          markTestSkipped(reason);
          return;
        }

        final roomId = selectedRoomId;
        _log('selected roomId=$roomId for $recordDurationMinutes-minute recording');

        String? sourcePath;
        try {

          await _waitUntilRecordingStopped(
            roomId,
            timeout: waitRecordingTimeout,
          );

          sourcePath = await _waitForRecordedFilePath(
            roomId,
            timeout: waitRecordFileTimeout,
          );
          expect(sourcePath != null && sourcePath.isNotEmpty, isTrue,
              reason: '找不到 room=$roomId 的錄製檔');

          final recordedPath = sourcePath ?? '';
          final ffmpegCoreLogBaseline =
              (await _loadFfmpegCoreLinesFromBootstrapLog()).length;

          final enqueue = await enqueueConvertTask(recordedPath, deleteOriginal: false); // 轉換任務内部用 ffmpeg
          expect(
            [200, 201, 202, 204, 409].contains(enqueue.statusCode),
            isTrue,
            reason:
                '加入轉檔佇列失敗 status=${enqueue.statusCode} body=${enqueue.bodyPreview()}',
          );

          String? taskId;
          if (enqueue.body.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(enqueue.body);
              if (decoded is Map) {
                taskId = asString(decoded['task_id']);
              }
            } catch (_) {
              // Ignore parse failure and fallback to source path matching.
            }
          }

          await _waitUntilConvertDone(
            sourcePath: recordedPath,
            timeout: waitConvertTimeout,
            taskId: taskId,
          );

          final convertedPath = await _findConvertedOutputPath(recordedPath);
          expect(convertedPath != null && convertedPath.isNotEmpty, isTrue,
              reason: '轉檔完成後找不到對應輸出檔，source=$recordedPath');
          _log('convert success source=$recordedPath output=$convertedPath');

          await _expectAndPrintNewFfmpegCoreBootstrapLogs(
            baselineCount: ffmpegCoreLogBaseline,
            scenario: 'Convert API',
          );
        } finally {
          try {
            await stopRecording(roomId);
          } catch (_) {
            // Ignore cleanup errors.
          }
          await shutdownServiceSafely(
            tester,
            inFlightLabels: inFlightPowerLabels,
            startLabels: startLabels,
            stopLabels: stopLabels,
            logTag: _logTag,
          );
        }
      },
      timeout: isCiEnv()
          ? const Timeout(Duration(minutes: 18))
          : const Timeout(Duration(minutes: 8)),
      skip: !Platform.isAndroid,
    );

    testWidgets(
      '啟動 app 後錄製並透過設定自動轉 MP4',
      (tester) async {
        const maxStartCandidates = 12;
        final recordDurationMinutes = isCiEnv() ? 5 : 1;
        final waitRecordingTimeout =
            isCiEnv() ? const Duration(minutes: 8) : const Duration(minutes: 3);
        final waitRecordFileTimeout =
            isCiEnv() ? const Duration(minutes: 2) : const Duration(seconds: 45);
        final waitConvertTimeout =
            isCiEnv() ? const Duration(minutes: 6) : const Duration(minutes: 3);
        final startLabels = labelsForKey('start');
        final stopLabels = labelsForKey('stop');
        final inFlightPowerLabels =
            labelsForKeys(['startingShort', 'stoppingShort']);
        final backendRunningLabels = labelsForKey('backendRunning');
        final settingsLabels = labelsForKey('settings');
        final convertToMp4Labels = labelsForKey('convertToMp4Title');

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await ensureForegroundNotificationPermissionGranted(logTag: _logTag);

        final previousAutoConvert = await _setConvertToMp4FromSettings(
          tester,
          settingsLabels: settingsLabels,
          convertToMp4Labels: convertToMp4Labels,
          enabled: true,
        );

        await tapPowerButton(
          tester,
          startLabels: startLabels,
          stopLabels: stopLabels,
          logTag: _logTag,
        );
        await waitForAnyText(tester, backendRunningLabels, logTag: _logTag);

        final liveRoomPool = await fetchLiveBroadcastRoomIDs();
        if (liveRoomPool.isEmpty) {
          markTestSkipped('broadcast API 無可用直播間，略過錄製轉檔測試');
          return;
        }

        final candidateCount = min(liveRoomPool.length, maxStartCandidates);
        final candidateRoomIds = pickDistinctRoomIDs(liveRoomPool, candidateCount);
        _log('candidates: $candidateRoomIds');

        int? selectedRoomId;
        final skippedReasons = <String>[];

        for (final roomId in candidateRoomIds) {
          final startResult =
              await startRecording(roomId, durationMinutes: recordDurationMinutes);
          final code = startResult.statusCode;
          final preview = startResult.bodyPreview();

          if ([200, 201, 202, 204, 409].contains(code)) {
            selectedRoomId = roomId;
            _log('start recording success roomId=$roomId statusCode=$code');
            break;
          }

          if (code == 400) {
            final reason = 'roomId=$roomId statusCode=400 body="$preview"';
            skippedReasons.add(reason);
            _log('skip candidate: $reason');
            continue;
          }

          fail('開始錄製失敗（非可忽略錯誤）: roomId=$roomId statusCode=$code body="$preview"');
        }

        if (selectedRoomId == null) {
          final reason = '所有候選直播間皆非直播狀態，skipped=$skippedReasons';
          _log('skip test: $reason');
          markTestSkipped(reason);
          return;
        }

        final roomId = selectedRoomId;
        _log('selected roomId=$roomId for $recordDurationMinutes-minute recording');

        String? sourcePath;
        try {
          await _waitUntilRecordingStopped(
            roomId,
            timeout: waitRecordingTimeout,
          );

          sourcePath = await _waitForRecordedFilePath(
            roomId,
            timeout: waitRecordFileTimeout,
          );
          expect(sourcePath != null && sourcePath.isNotEmpty, isTrue,
              reason: '找不到 room=$roomId 的錄製檔');

          final recordedPath = sourcePath ?? '';
          final ffmpegCoreLogBaseline =
              (await _loadFfmpegCoreLinesFromBootstrapLog()).length;

          final queuedTask = await _waitForConvertTaskEnqueued(
            sourcePath: recordedPath,
            timeout: waitConvertTimeout,
          );
          expect(
            queuedTask != null,
            isTrue,
            reason: '自動轉檔未進入轉換隊列，source=$recordedPath',
          );

          await _waitUntilConvertDone(
            sourcePath: recordedPath,
            timeout: waitConvertTimeout,
            taskId: (queuedTask?.taskId ?? '').isEmpty ? null : queuedTask?.taskId,
          );

          final convertedPath = await _findConvertedOutputPath(recordedPath);
          expect(convertedPath != null && convertedPath.isNotEmpty, isTrue,
              reason: '轉檔完成後找不到對應輸出檔，source=$recordedPath');
          _log('auto convert success source=$recordedPath output=$convertedPath');

          await _expectAndPrintNewFfmpegCoreBootstrapLogs(
            baselineCount: ffmpegCoreLogBaseline,
            scenario: 'Auto Convert MP4',
          );
        } finally {
          try {
            await stopRecording(roomId);
          } catch (_) {
            // Ignore cleanup errors.
          }

          await shutdownServiceSafely(
            tester,
            inFlightLabels: inFlightPowerLabels,
            startLabels: startLabels,
            stopLabels: stopLabels,
            logTag: _logTag,
          );

          try {
            await _setConvertToMp4FromSettings(
              tester,
              settingsLabels: settingsLabels,
              convertToMp4Labels: convertToMp4Labels,
              enabled: previousAutoConvert,
            );
          } catch (e) {
            _log('restore convertToMp4 failed: $e');
          }

        }
      },
      timeout: isCiEnv()
          ? const Timeout(Duration(minutes: 18))
          : const Timeout(Duration(minutes: 8)),
      skip: !Platform.isAndroid,
    );
  });
}
