import 'dart:async';
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

enum FfmpegLogFreshnessPolicy { fail, warn }

const _noNewFfmpegLinesPolicy = FfmpegLogFreshnessPolicy.warn;

typedef _FfmpegExecuteNative = ffi.Int32 Function(
  ffi.Int32 argc,
  ffi.Pointer<ffi.Pointer<ffi.Char>> argv,
);
typedef _FfmpegExecuteDart = int Function(
  int argc,
  ffi.Pointer<ffi.Pointer<ffi.Char>> argv,
);

void _log(String message) => testLog(_logTag, message);

Future<void> _waitForHomeReady(
  WidgetTester tester,
  Iterable<String> startLabels,
) async {
  await waitForAnyText(
    tester,
    startLabels,
    timeout: const Duration(seconds: 30),
    logTag: _logTag,
  );
}

Future<void> _waitForFfmpegCoreLogGrowth({
  required int baselineCount,
  Duration timeout = const Duration(seconds: 30),
}) async {
  const poll = Duration(seconds: 2);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;
  for (var i = 0; i < rounds; i++) {
    final lines = await _loadFfmpegCoreLinesFromBootstrapLogOnce();
    if (lines.length > baselineCount) {
      return;
    }
    await Future<void>.delayed(poll);
  }
  _log('ffmpeg_core log growth not observed within ${timeout.inSeconds}s');
}

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

String _formatRecordTimestamp(DateTime ts) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${ts.year}${two(ts.month)}${two(ts.day)}_${two(ts.hour)}${two(ts.minute)}${two(ts.second)}';
}

Future<File> _stageDemoRecordFlv() async {
  final workDir = await Directory.systemTemp.createTemp('ffmpeg-it-');
  try {
    final inputFile = await _downloadDemoFlv(workDir);
    final appSupportDir = await getApplicationSupportDirectory();
    final recordsDir = Directory('${appSupportDir.path}${Platform.pathSeparator}records');
    await recordsDir.create(recursive: true);

    final timestamp = _formatRecordTimestamp(DateTime.now());
    final fileName = 'demo-$timestamp.flv';
    final destPath = '${recordsDir.path}${Platform.pathSeparator}$fileName';
    final destFile = await inputFile.copy(destPath);
    _log('demo flv staged: path=${destFile.path} bytes=${await destFile.length()}');
    return destFile;
  } finally {
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
  }
}

String _parentPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  if (idx <= 0) return '';
  return normalized.substring(0, idx);
}

String _recordRelativePath(String absolutePath) {
  final normalized = absolutePath.replaceAll('\\', '/');
  final marker = '/records/';
  final idx = normalized.indexOf(marker);
  if (idx == -1) return _fileNameFromPath(absolutePath);
  return normalized.substring(idx + marker.length);
}

DateTime? _recordedFileTimestamp(String fileName) {
  final match = RegExp(r'-(\d{8})_(\d{6})\.(?:flv|ts|fmp4)$', caseSensitive: false)
      .firstMatch(fileName);
  if (match == null) return null;

  final d = match.group(1)!;
  final t = match.group(2)!;
  return DateTime(
    int.parse(d.substring(0, 4)),
    int.parse(d.substring(4, 6)),
    int.parse(d.substring(6, 8)),
    int.parse(t.substring(0, 2)),
    int.parse(t.substring(2, 4)),
    int.parse(t.substring(4, 6)),
  );
}

DateTime? _parseFlexibleItemTimestamp(dynamic value) {
  if (value == null) return null;

  if (value is num) {
    final n = value.toInt();
    final abs = n.abs();
    if (abs > 1000000000000000) {
      return DateTime.fromMicrosecondsSinceEpoch(n ~/ 1000, isUtc: true).toLocal();
    }
    if (abs > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toLocal();
    }
    if (abs > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true).toLocal();
    }
  }

  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final numValue = int.tryParse(text);
  if (numValue != null) {
    return _parseFlexibleItemTimestamp(numValue);
  }

  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime? _recordItemTimestamp(Map<String, dynamic> item) {
  final fromName = _recordedFileTimestamp(asString(item['name']));
  if (fromName != null) return fromName;

  const keys = <String>[
    'modified_at',
    'updated_at',
    'mtime',
    'modified',
    'created_at',
    'ctime',
    'created',
    'time',
  ];
  for (final key in keys) {
    final parsed = _parseFlexibleItemTimestamp(item[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

Future<void> _cleanupRecordsFoldersIfCi() async {
  if (!isCiEnv()) {
    return;
  }

  final candidates = <String>{};
  final appSupportDir = await getApplicationSupportDirectory();
  candidates.add('${appSupportDir.path}${Platform.pathSeparator}records');

  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    candidates.add('${appDocDir.path}${Platform.pathSeparator}records');
  } catch (_) {
    // Best-effort cleanup only.
  }

  try {
    final ext = await getExternalStorageDirectory();
    if (ext != null) {
      candidates.add('${ext.path}${Platform.pathSeparator}records');
    }
  } catch (_) {
    // Best-effort cleanup only.
  }

  var scanned = 0;
  var cleaned = 0;
  for (final recordsPath in candidates) {
    final dir = Directory(recordsPath);
    scanned++;
    if (_fileNameFromPath(dir.path) != 'records') {
      _log('ci cleanup skip non-records path=$recordsPath');
      continue;
    }
    if (!await dir.exists()) {
      continue;
    }

    final children = await dir.list(followLinks: false).toList();
    for (final entity in children) {
      try {
        await entity.delete(recursive: true);
        cleaned++;
      } catch (e) {
        _log('ci cleanup failed: target=${entity.path} error=$e');
      }
    }
  }

  _log('ci cleanup records done: scanned=$scanned cleanedChildren=$cleaned');
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
      malloc.free(ptr);
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

Future<List<Map<String, dynamic>>> _listRecordedFiles(int roomId) async {
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
    return const <Map<String, dynamic>>[];
  }

  return matched;
}

Future<String?> _findRecordedFilePath(
  int roomId, {
  Set<String> excludePaths = const <String>{},
}) async {
  final matched = await _listRecordedFiles(roomId);
  if (matched.isEmpty) {
    return null;
  }

  final fresh = matched.where((item) {
    final path = asString(item['path']);
    return path.isNotEmpty && !excludePaths.contains(path);
  }).toList(growable: false);

  if (fresh.isEmpty) {
    _log(
      'find record: room=$roomId only old files found; total=${matched.length} excluded=${excludePaths.length}',
    );
    return null;
  }

  fresh.sort((a, b) {
    final aTs = _recordItemTimestamp(a);
    final bTs = _recordItemTimestamp(b);
    final tsCompare = (bTs?.millisecondsSinceEpoch ?? -1).compareTo(
      aTs?.millisecondsSinceEpoch ?? -1,
    );
    if (tsCompare != 0) return tsCompare;

    final sizeCompare = asInt(b['size']).compareTo(asInt(a['size']));
    if (sizeCompare != 0) return sizeCompare;
    return asString(b['name']).compareTo(asString(a['name']));
  });

  final picked = asString(fresh.first['path']);
  _log(
    'find record: room=$roomId pick=$picked candidates=${matched.length} fresh=${fresh.length} excluded=${excludePaths.length}',
  );
  return picked;
}

Future<Set<String>> _listFreshRecordedPaths(
  int roomId, {
  Set<String> excludePaths = const <String>{},
}) async {
  final matched = await _listRecordedFiles(roomId);
  return matched
      .map((item) => asString(item['path']))
      .where((path) => path.isNotEmpty && !excludePaths.contains(path))
      .toSet();
}

Future<String?> _waitForRecordedFilePath(
  int roomId, {
  required Duration timeout,
  Set<String> excludePaths = const <String>{},
}) async {
  const poll = Duration(seconds: 5);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;
  for (var i = 0; i < rounds; i++) {
    final path = await _findRecordedFilePath(roomId, excludePaths: excludePaths);
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

Future<String?> _findConvertedOutputPathByCandidates(
  String sourcePath, {
  Set<String> sourcePathCandidates = const <String>{},
}) async {
  final dirPath = _parentPath(sourcePath);
  final stems = <String>{
    _fileStem(sourcePath),
    ...sourcePathCandidates.map(_fileStem),
  };
  final items = await browseFilesAtPath(browsePath: dirPath);

  final candidates = items.where((item) {
    if (item['is_dir'] == true) return false;
    final name = asString(item['name']);
    final lowerName = name.toLowerCase();
    final converted = lowerName.endsWith('.mp4') || lowerName.endsWith('.mkv');
    if (!converted) return false;
    return stems.any((stem) => stem.isNotEmpty && name.contains(stem));
  }).toList(growable: false);

  if (candidates.isEmpty) {
    return null;
  }

  candidates.sort((a, b) => asInt(b['size']).compareTo(asInt(a['size'])));
  return asString(candidates.first['path']);
}

Future<List<String>> _loadFfmpegCoreLinesFromBootstrapLogOnce() async {
  final appSupportDir = await getApplicationSupportDirectory();
  final sourceDir = Directory(appSupportDir.path);

  if (!await sourceDir.exists()) {
    _log('bootstrap.log not found: path=${appSupportDir.path}');
    return const <String>[];
  }

  final entities = await sourceDir.list().toList();
  final logFiles = entities.whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return name.startsWith('bootstrap') && name.endsWith('.log');
  }).toList();

  if (logFiles.isEmpty) {
    _log('bootstrap.log not found: path=${appSupportDir.path}');
    return const <String>[];
  }

  // Sort by name so lumberjack rotated logs come first and bootstrap.log is last.
  logFiles.sort((a, b) => a.path.compareTo(b.path));

  final allLines = <String>[];
  for (final file in logFiles) {
    try {
      final lines = await file.readAsLines();
      allLines.addAll(lines);
    } catch (e) {
      _log('bootstrap.log read failed: path=${file.path} error=$e');
    }
  }

  final ffmpegCoreLines = <String>[];
  var inFfmpegBlock = false;
  final currentBlock = <String>[];

  for (final line in allLines) {
    final hasFfmpegHead = line.contains('[FFMPEG]');
    final hasFfmpegTail = line.contains('component=ffmpeg_core');

    if (hasFfmpegHead) {
      inFfmpegBlock = true;
      currentBlock
        ..clear()
        ..add(line);
      if (hasFfmpegTail) {
        if (currentBlock.length >= 5) {
          ffmpegCoreLines.addAll(currentBlock);
        }
        currentBlock.clear();
        inFfmpegBlock = false;
      }
      continue;
    }

    if (!inFfmpegBlock) {
      continue;
    }

    currentBlock.add(line);
    if (hasFfmpegTail) {
      if (currentBlock.length >= 5) {
        ffmpegCoreLines.addAll(currentBlock);
      }
      currentBlock.clear();
      inFfmpegBlock = false;
    }
  }

  _log(
    'bootstrap.log loaded: files=${logFiles.length} totalLines=${allLines.length} ffmpegCoreLines=${ffmpegCoreLines.length + currentBlock.length}',
  );
  return ffmpegCoreLines;
}

Future<List<String>> _waitForFfmpegCoreLinesFromBootstrapLog() async {
  const waitTimeout = Duration(minutes: 3);
  const poll = Duration(seconds: 5);
  final rounds = waitTimeout.inMilliseconds ~/ poll.inMilliseconds;

  for (var attempt = 0; attempt < rounds; attempt++) {
    final ffmpegCoreLines = await _loadFfmpegCoreLinesFromBootstrapLogOnce();
    if (ffmpegCoreLines.isNotEmpty) {
      return ffmpegCoreLines;
    }
    if (attempt < rounds - 1) {
      await Future<void>.delayed(poll);
    }
  }

  _log('bootstrap.log loaded: wait timeout; ffmpeg_core tail not completed');
  return const <String>[];
}

Future<void> _expectAndPrintNewFfmpegCoreBootstrapLogs({
  required int baselineCount,
  required String scenario,
  bool requireNewLines = true,
  FfmpegLogFreshnessPolicy noNewLinesPolicy = FfmpegLogFreshnessPolicy.fail,
}) async {
  List<String> ffmpegCoreLines = const <String>[];
  ffmpegCoreLines = await _waitForFfmpegCoreLinesFromBootstrapLog();

  final start = baselineCount <= ffmpegCoreLines.length ? baselineCount : 0;
  final newLines = ffmpegCoreLines.skip(start).toList(growable: false);

  final hasNewLines = newLines.isNotEmpty;
  final hasAnyLines = ffmpegCoreLines.isNotEmpty;

  if (!hasAnyLines) {
    if (noNewLinesPolicy == FfmpegLogFreshnessPolicy.warn) {
      _log('🚨🚨🚨 未找到 ffmpeg_core 日誌 🚨🚨🚨');
      _log('🚨 場景=$scenario | baseline=$baselineCount | total=${ffmpegCoreLines.length} 🚨');
      _log('🚨 警告：缺少 ffmpeg 日誌可能導致轉換調試困難（測試繼續） 🚨');
      await printBootstrapLogsIfAny(
        scenario: 'ffmpeg_core missing ($scenario)',
        logTag: _logTag,
      );
      return;
    }
    _log('WARNING: bootstrap.log missing component=ffmpeg_core lines, scenario=$scenario');
  } else if (requireNewLines && !hasNewLines) {
    if (noNewLinesPolicy == FfmpegLogFreshnessPolicy.warn) {
      _log('🚨🚨🚨 轉換時未產生新的 ffmpeg 日誌 🚨🚨🚨');
      _log('🚨 場景=$scenario | baseline=$baselineCount | total=${ffmpegCoreLines.length} 🚨');
      _log('🚨 警告：缺少 ffmpeg 日誌可能導致轉換調試困難（測試繼續） 🚨');
      // Keep printing existing ffmpeg_core lines below when available.
    } else {
      _log('WARNING: no new ffmpeg_core lines detected, scenario=$scenario');
    }
  }

  if (noNewLinesPolicy != FfmpegLogFreshnessPolicy.warn) {
    final expectOk = requireNewLines ? hasNewLines : hasAnyLines;
    expect(
      expectOk,
      isTrue,
      reason: 'bootstrap.log 缺少 component=ffmpeg_core 日誌，scenario=$scenario',
    );
  }

  if (!hasAnyLines) {
    return;
  }

  final linesToPrint = hasNewLines ? newLines : ffmpegCoreLines;
  _log('===== bootstrap.log component=ffmpeg_core ($scenario) =====');
  for (final line in linesToPrint.take(80)) {
    _log(line);
  }
  if (linesToPrint.length > 80) {
    _log('... ${linesToPrint.length - 80} more ffmpeg_core lines omitted ...');
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

  // Wait explicitly for SettingsDrawerSheet to appear in the widget tree.
  // pumpAndSettle alone is not sufficient because _bootstrap() fires async
  // SharedPreferences reads that keep scheduling setState, and the bottom
  // sheet animation may not have committed the widget yet.
  const sheetPollInterval = Duration(milliseconds: 200);
  const sheetPollMax = 30; // 6 seconds total
  for (var i = 0; i < sheetPollMax; i++) {
    await tester.pump(sheetPollInterval);
    if (find.byType(SettingsDrawerSheet).evaluate().isNotEmpty) break;
    if (i == sheetPollMax - 1) {
      _log('WARNING: SettingsDrawerSheet not found after ${sheetPollMax * sheetPollInterval.inMilliseconds}ms; continuing anyway');
    }
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 200));

  await waitForCondition(
    tester,
    timeout: const Duration(seconds: 8),
    step: sheetPollInterval,
    logTag: _logTag,
    description: 'SettingsDrawerSheet or target label',
    condition: () {
      final sheetFinder = find.byType(SettingsDrawerSheet);
      if (sheetFinder.evaluate().isNotEmpty) {
        return true;
      }
      return convertToMp4Labels.any(
        (label) => find.text(label).evaluate().isNotEmpty,
      );
    },
  );

  Finder? scrollableFinder;
  final sheetFinder = find.byType(SettingsDrawerSheet);
  if (sheetFinder.evaluate().isNotEmpty) {
    final sheetScrollable = find.descendant(
      of: sheetFinder,
      matching: find.byType(Scrollable),
    );
    if (sheetScrollable.evaluate().isNotEmpty) {
      scrollableFinder = sheetScrollable;
    }
  }

  scrollableFinder ??= find.byType(Scrollable).evaluate().isNotEmpty
      ? find.byType(Scrollable)
      : null;

  if (scrollableFinder == null) {
    _log('WARNING: no Scrollable found in settings sheet; continuing without drag');
  }

  final targetLabel = convertToMp4Labels.first;
  final labelFinder = find.text(targetLabel);

  if (scrollableFinder != null && labelFinder.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      labelFinder,
      scrollableFinder.first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }

  await waitForAnyText(tester, convertToMp4Labels, logTag: _logTag);

  final visibleLabelFinder =
      findFirstVisibleText(convertToMp4Labels, logTag: _logTag).first;
  await tester.ensureVisible(visibleLabelFinder);
  await tester.pump(const Duration(milliseconds: 120));

  final tileFinder = find.ancestor(
    of: visibleLabelFinder,
    matching: find.byType(SwitchListTile),
  );
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
  required Set<String> sourcePathCandidates,
  required Duration timeout,
}) async {
  const poll = Duration(seconds: 1);
  final rounds = timeout.inMilliseconds ~/ poll.inMilliseconds;
  final normalizedCandidates = sourcePathCandidates
      .where((path) => path.isNotEmpty)
      .toSet();
  final fallbackSource = normalizedCandidates.isNotEmpty
      ? normalizedCandidates.first
      : '';

  for (var i = 0; i < rounds; i++) {
    final tasks = await listConvertTasks();

    // 增強調試日誌
    if (tasks.isNotEmpty && i < 3) {  // 只在前 3 次輪詢時打印詳細信息
      _log('convert enqueue poll=${i + 1}/$rounds queue=${tasks.length}');
      for (final task in tasks) {
        _log('  task: inputPath="${task.inputPath}"');
      }
      _log('  expected sources=${normalizedCandidates.length} fallback="$fallbackSource"');
    }

    final matched = tasks.where((task) {
      if (normalizedCandidates.isEmpty) {
        return fallbackSource.isNotEmpty &&
            (task.inputPath == fallbackSource || task.inputPath.endsWith(fallbackSource));
      }
      for (final candidate in normalizedCandidates) {
        if (task.inputPath == candidate || task.inputPath.endsWith(candidate)) {
          return true;
        }
      }
      return false;
    }).toList();
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
      '啟動服務並透過 Convert API 轉檔',
      (tester) async {
        final waitConvertTimeout =
            isCiEnv() ? const Duration(minutes: 8) : const Duration(minutes: 4);
        final startLabels = labelsForKey('start');
        final stopLabels = labelsForKey('stop');
        final inFlightPowerLabels =
            labelsForKeys(['startingShort', 'stoppingShort']);
        final backendRunningLabels = labelsForKey('backendRunning');

        app.main();
        await _waitForHomeReady(tester, startLabels);

        await ensureForegroundNotificationPermissionGranted(logTag: _logTag);

        await tapPowerButton(
          tester,
          startLabels: startLabels,
          stopLabels: stopLabels,
          logTag: _logTag,
        );
        await waitForAnyText(
          tester,
          backendRunningLabels,
          logTag: _logTag,
          waitMode: WaitMode.realtime,
        );
        await waitUntilPowerButtonStable(
          tester,
          inFlightLabels: inFlightPowerLabels,
          startLabels: startLabels,
          stopLabels: stopLabels,
          logTag: _logTag,
          waitMode: WaitMode.realtime,
        );

        File? stagedFile;
        String? sourcePath;
        try {
          stagedFile = await _stageDemoRecordFlv();
          sourcePath = _recordRelativePath(stagedFile.path);

          final ffmpegCoreLogBaseline =
              (await _loadFfmpegCoreLinesFromBootstrapLogOnce()).length;

          final enqueue = await enqueueConvertTask(sourcePath, deleteOriginal: false);
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
            sourcePath: sourcePath,
            timeout: waitConvertTimeout,
            taskId: taskId,
          );

          final convertedPath = await _findConvertedOutputPath(sourcePath);
          expect(convertedPath != null && convertedPath.isNotEmpty, isTrue,
              reason: '轉檔完成後找不到對應輸出檔，source=$sourcePath');
          _log('convert success source=$sourcePath output=$convertedPath');

          await _waitForFfmpegCoreLogGrowth(
            baselineCount: ffmpegCoreLogBaseline,
            timeout: const Duration(seconds: 30),
          );

          await _expectAndPrintNewFfmpegCoreBootstrapLogs(
            baselineCount: ffmpegCoreLogBaseline,
            scenario: 'Convert API (demo file)',
            noNewLinesPolicy: _noNewFfmpegLinesPolicy,
          );
        } catch (e, st) {
          _log('convert api failed: $e');
          _log('$st');
          await printBootstrapLogsIfAny(
            scenario: 'Convert API failed',
            logTag: _logTag,
          );
          rethrow;
        } finally {
          if (stagedFile != null) {
            try {
              if (await stagedFile.exists()) {
                await stagedFile.delete();
              }
            } catch (_) {
              // Best-effort cleanup only.
            }
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
          ? const Timeout(Duration(minutes: 24))
          : const Timeout(Duration(minutes: 10)),
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
        await _waitForHomeReady(tester, startLabels);

        await _cleanupRecordsFoldersIfCi();

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
        await waitForAnyText(
          tester,
          backendRunningLabels,
          logTag: _logTag,
          waitMode: WaitMode.realtime,
        );
        await waitUntilPowerButtonStable(
          tester,
          inFlightLabels: inFlightPowerLabels,
          startLabels: startLabels,
          stopLabels: stopLabels,
          logTag: _logTag,
          waitMode: WaitMode.realtime,
        );

        final liveRoomPool = await fetchLiveBroadcastRoomIDs();
        if (liveRoomPool.isEmpty) {
          markTestSkipped('broadcast API 無可用直播間，略過錄製轉檔測試');
          return;
        }

        final candidateCount = min(liveRoomPool.length, maxStartCandidates);
        final candidateRoomIds = pickDistinctRoomIDs(liveRoomPool, candidateCount);
        _log('candidates: $candidateRoomIds');

        int? selectedRoomId;
        Set<String> selectedRoomExistingPaths = <String>{};
        final skippedReasons = <String>[];

        for (final roomId in candidateRoomIds) {
          final preExistingFiles = await _listRecordedFiles(roomId);
          final preExistingPaths = preExistingFiles
              .map((item) => asString(item['path']))
              .where((path) => path.isNotEmpty)
              .toSet();

          ApiCallResult? startResult;
          Object? transientError;
          const startAttemptLimit = 2;
          for (var attempt = 1; attempt <= startAttemptLimit; attempt++) {
            try {
              startResult = await startRecording(
                roomId,
                durationMinutes: recordDurationMinutes,
              );
              break;
            } on TimeoutException catch (e) {
              transientError = e;
              _log(
                'start recording timeout roomId=$roomId attempt=$attempt/$startAttemptLimit',
              );
            } on SocketException catch (e) {
              transientError = e;
              _log(
                'start recording socket error roomId=$roomId attempt=$attempt/$startAttemptLimit error=$e',
              );
            } on HttpException catch (e) {
              transientError = e;
              _log(
                'start recording http error roomId=$roomId attempt=$attempt/$startAttemptLimit error=$e',
              );
            }

            if (attempt < startAttemptLimit) {
              await Future<void>.delayed(const Duration(seconds: 2));
            }
          }

          if (startResult == null) {
            final reason =
                'roomId=$roomId startRecording transient failure=${transientError ?? 'unknown'}';
            skippedReasons.add(reason);
            _log('skip candidate: $reason');
            continue;
          }

          final code = startResult.statusCode;
          final preview = startResult.bodyPreview();

          if ([200, 201, 202, 204, 409].contains(code)) {
            selectedRoomId = roomId;
            selectedRoomExistingPaths = preExistingPaths;
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
            excludePaths: selectedRoomExistingPaths,
          );
          expect(sourcePath != null && sourcePath.isNotEmpty, isTrue,
              reason: '找不到 room=$roomId 的錄製檔');

          final recordedPath = sourcePath ?? '';
          final ffmpegCoreLogBaseline =
              (await _loadFfmpegCoreLinesFromBootstrapLogOnce()).length;
          final freshSources = await _listFreshRecordedPaths(
            roomId,
            excludePaths: selectedRoomExistingPaths,
          );
          final sourceCandidates = freshSources.isNotEmpty
              ? freshSources
              : <String>{recordedPath};

          final queuedTask = await _waitForConvertTaskEnqueued(
            sourcePathCandidates: sourceCandidates,
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

          final convertedPath = await _findConvertedOutputPathByCandidates(
            recordedPath,
            sourcePathCandidates: sourceCandidates,
          );
          expect(convertedPath != null && convertedPath.isNotEmpty, isTrue,
              reason: '轉檔完成後找不到對應輸出檔，source=$recordedPath');
          _log('auto convert success source=$recordedPath output=$convertedPath');

          await _waitForFfmpegCoreLogGrowth(
            baselineCount: ffmpegCoreLogBaseline,
            timeout: const Duration(seconds: 30),
          );

          final requireNewLines = ffmpegCoreLogBaseline == 0;
          await _expectAndPrintNewFfmpegCoreBootstrapLogs(
            baselineCount: ffmpegCoreLogBaseline,
            scenario: 'Auto Convert MP4',
            requireNewLines: requireNewLines,
            noNewLinesPolicy: _noNewFfmpegLinesPolicy,
          );
        } catch (e, st) {
          _log('auto convert failed: $e');
          _log('$st');
          await printBootstrapLogsIfAny(
            scenario: 'Auto Convert MP4 failed',
            logTag: _logTag,
          );
          rethrow;
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
          ? const Timeout(Duration(minutes: 24))
          : const Timeout(Duration(minutes: 10)),
      skip: !Platform.isAndroid,
    );
  });
}
