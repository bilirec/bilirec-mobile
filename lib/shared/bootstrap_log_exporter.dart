import 'dart:io';

import 'package:bilirec/shared/debugger.dart';
import 'package:bilirec/shared/export_path_display.dart';
import 'package:bilirec/shared/file_exporter.dart';
import 'package:bilirec/shared/legacy_android_compatible.dart';
import 'package:bilirec/shared/saf_export_gateway.dart';
import 'package:path_provider/path_provider.dart';

sealed class BootstrapLogExportResult {}

class BootstrapLogExported implements BootstrapLogExportResult {
  const BootstrapLogExported({
    required this.path,
    required this.fileCount,
  });

  final String path;
  final int fileCount;
}

class BootstrapLogNotFound implements BootstrapLogExportResult {
  const BootstrapLogNotFound();
}

class BootstrapLogCancelled implements BootstrapLogExportResult {
  const BootstrapLogCancelled();
}

class BootstrapLogNotWritable implements BootstrapLogExportResult {
  const BootstrapLogNotWritable();
}

class BootstrapLogFailed implements BootstrapLogExportResult {
  const BootstrapLogFailed(this.error);

  final Object error;
}

class BootstrapLogExporter {
  BootstrapLogExporter({
    FileExporter? fileExporter,
    SafExportGateway? safExportGateway,
  })  : _fileExporter = fileExporter ?? FileExporter(),
        _safExportGateway = safExportGateway ?? SafExportGateway();

  final FileExporter _fileExporter;
  final SafExportGateway _safExportGateway;

  Future<BootstrapLogExportResult> export({
    required String dialogTitle,
  }) async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final sourceDir = Directory(appSupport.path);

      if (!await sourceDir.exists()) {
        return const BootstrapLogNotFound();
      }

      final entities = await sourceDir.list().toList();
      final logFiles = entities.whereType<File>().where((f) {
        final name = f.uri.pathSegments.last;
        return name.startsWith('bootstrap') && name.endsWith('.log');
      }).toList();

      if (logFiles.isEmpty) {
        return const BootstrapLogNotFound();
      }

      logFiles.sort((a, b) => a.path.compareTo(b.path));

      final now = DateTime.now();
      final timestamp =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final outputFileName = 'bootstrap_$timestamp.log';

      final exported = await _fileExporter.exportWithSafFallback(
        dialogTitle: dialogTitle,
        onSafFailed: (error) {
          debugLog(
            'SAF bootstrap export failed, fallback to file path export: $error',
          );
        },
        writeWithSaf: (treeUri) async {
          final result =
              await _safExportGateway.writeMergedTextFileFromLocalFiles(
            treeUri: treeUri,
            fileName: outputFileName,
            sourceFiles: logFiles,
            mimeType: 'text/plain',
          );
          return result.uri.toString();
        },
        writeWithPath: (selectedDir) async {
          final writable =
              await ensureDirectoryWritableWithPermissionFromVersion(
                  selectedDir);
          if (!writable) {
            throw const ExportTargetNotWritableException();
          }

          final targetPath =
              '$selectedDir${Platform.pathSeparator}$outputFileName';
          final wrote = await _writeBootstrapLogWithPermissionRecovery(
            logFiles: logFiles,
            selectedDir: selectedDir,
            targetPath: targetPath,
          );
          if (!wrote) {
            throw const ExportTargetNotWritableException();
          }

          return targetPath;
        },
      );
      if (exported == null) {
        debugLog('Bootstrap log export cancelled by user');
        return const BootstrapLogCancelled();
      }

      return BootstrapLogExported(
        path: formatExportPathForDisplay(exported.location),
        fileCount: logFiles.length,
      );
    } on ExportTargetNotWritableException {
      debugLog('Bootstrap log export target not writable');
      return const BootstrapLogNotWritable();
    } catch (e) {
      return BootstrapLogFailed(e);
    }
  }

  Future<bool> _writeBootstrapLogWithPermissionRecovery({
    required List<File> logFiles,
    required String selectedDir,
    required String targetPath,
  }) async {
    var retriedAfterPermissionRequest = false;

    while (true) {
      final targetFile = File(targetPath);
      try {
        await _mergeBootstrapLogsIntoTarget(logFiles, targetFile);
        return true;
      } catch (e) {
        if (retriedAfterPermissionRequest ||
            !isPermissionLikeStorageFailure(e)) {
          rethrow;
        }

        retriedAfterPermissionRequest = true;
        debugLog(
          'Bootstrap log export failed with permission-like error, requesting storage permission retry: $e',
        );

        final granted = await requestExternalStoragePermissionFromVersion();
        if (!granted) {
          return false;
        }

        final writable = await canWriteToDirectoryPath(selectedDir);
        if (!writable) {
          return false;
        }

        try {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
        } catch (_) {
          // Best-effort cleanup before retry.
        }
      }
    }
  }

  Future<void> _mergeBootstrapLogsIntoTarget(
    List<File> logFiles,
    File targetFile,
  ) async {
    final sink = targetFile.openWrite(mode: FileMode.write);
    try {
      for (final file in logFiles) {
        await sink.addStream(file.openRead());
        sink.writeln();
      }
    } finally {
      await sink.close();
    }
  }
}
