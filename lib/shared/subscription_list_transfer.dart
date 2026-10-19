import 'dart:io';
import 'dart:typed_data';

import 'package:bilirec/shared/debugger.dart';
import 'package:bilirec/shared/export_path_display.dart';
import 'package:bilirec/shared/file_exporter.dart';
import 'package:bilirec/shared/legacy_android_compatible.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/saf_export_gateway.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

sealed class SubscriptionListTransferResult {}

class SubscriptionListNotFound implements SubscriptionListTransferResult {
  const SubscriptionListNotFound();
}

class SubscriptionListCancelled implements SubscriptionListTransferResult {
  const SubscriptionListCancelled();
}

class SubscriptionListNotWritable implements SubscriptionListTransferResult {
  const SubscriptionListNotWritable();
}

class SubscriptionListInvalidFile implements SubscriptionListTransferResult {
  const SubscriptionListInvalidFile();
}

class SubscriptionListSamePath implements SubscriptionListTransferResult {
  const SubscriptionListSamePath();
}

class SubscriptionListSucceeded implements SubscriptionListTransferResult {
  const SubscriptionListSucceeded(this.path);

  final String path;
}

class SubscriptionListFailed implements SubscriptionListTransferResult {
  const SubscriptionListFailed(this.error);

  final Object error;
}

class SubscriptionListTransfer {
  SubscriptionListTransfer({
    FileExporter? fileExporter,
    SafExportGateway? safExportGateway,
  })  : _fileExporter = fileExporter ?? FileExporter(),
        _safExportGateway = safExportGateway ?? SafExportGateway();

  final FileExporter _fileExporter;
  final SafExportGateway _safExportGateway;

  Future<File> resolveSubscribesDbFile() async {
    final develop = await Preferences.getDevelopEnvironmentSettings();
    final databaseDir = (develop['DATABASE_DIR'] ?? '').trim();
    if (databaseDir.isNotEmpty) {
      debugLog(
          'locating subscribes.db in $databaseDir${Platform.pathSeparator}subscribes.db');
      return File('$databaseDir${Platform.pathSeparator}subscribes.db');
    }

    final appSupport = await getApplicationSupportDirectory();
    final databasePath =
        '${appSupport.path}${Platform.pathSeparator}database${Platform.pathSeparator}subscribes.db';
    debugLog('locating subscribes.db in $databasePath');
    return File(databasePath);
  }

  static String formatTimestamp(DateTime now) {
    return '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  Future<SubscriptionListTransferResult> export({
    required String dialogTitle,
  }) async {
    try {
      final sourceFile = await resolveSubscribesDbFile();
      final sourceExists = await sourceFile.exists();
      if (!sourceExists) {
        return const SubscriptionListNotFound();
      }

      final outputFileName =
          'subscribes_${formatTimestamp(DateTime.now())}.db';

      final exported = await _fileExporter.exportWithSafFallback(
        dialogTitle: dialogTitle,
        onSafFailed: (error) {
          debugLog(
            'SAF subscription export failed, fallback to file path export: $error',
          );
        },
        writeWithSaf: (treeUri) async {
          final result = await _safExportGateway.copyLocalFileToDirectory(
            sourcePath: sourceFile.path,
            treeUri: treeUri,
            fileName: outputFileName,
            mimeType: 'application/x-sqlite3',
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
          await sourceFile.copy(targetPath);
          return targetPath;
        },
      );
      if (exported == null) {
        debugLog('Subscription list export cancelled by user');
        return const SubscriptionListCancelled();
      }

      return SubscriptionListSucceeded(
        formatExportPathForDisplay(exported.location),
      );
    } on ExportTargetNotWritableException {
      debugLog('Subscription list export target not writable');
      return const SubscriptionListNotWritable();
    } catch (e) {
      return SubscriptionListFailed(e);
    }
  }

  Future<SubscriptionListTransferResult> importPickedFile({
    required String? sourcePath,
    required Uint8List? bytes,
    required String sourceName,
  }) async {
    try {
      final hasDbExtension = sourceName.endsWith('.db') ||
          (sourcePath?.toLowerCase().endsWith('.db') ?? false);
      if ((sourcePath == null || sourcePath.isEmpty) && bytes == null) {
        return const SubscriptionListInvalidFile();
      }
      if (!hasDbExtension) {
        return const SubscriptionListInvalidFile();
      }

      final targetFile = await resolveSubscribesDbFile();
      await targetFile.parent.create(recursive: true);

      final normalizedSource = sourcePath?.replaceAll('\\', '/').toLowerCase();
      final normalizedTarget =
          targetFile.path.replaceAll('\\', '/').toLowerCase();
      if (normalizedSource != null && normalizedSource == normalizedTarget) {
        return const SubscriptionListSamePath();
      }

      if (await targetFile.exists()) {
        final backupPath =
            '${targetFile.path}.bak_${formatTimestamp(DateTime.now())}';
        await targetFile.copy(backupPath);
      }

      final wal = File('${targetFile.path}-wal');
      if (await wal.exists()) {
        await wal.delete();
      }
      final shm = File('${targetFile.path}-shm');
      if (await shm.exists()) {
        await shm.delete();
      }

      if (bytes != null) {
        await targetFile.writeAsBytes(bytes, flush: true);
      } else {
        await File(sourcePath!).copy(targetFile.path);
      }

      return SubscriptionListSucceeded(targetFile.path);
    } catch (e) {
      return SubscriptionListFailed(e);
    }
  }

  Future<SubscriptionListTransferResult> reset() async {
    try {
      final targetFile = await resolveSubscribesDbFile();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      final wal = File('${targetFile.path}-wal');
      if (await wal.exists()) {
        await wal.delete();
      }
      final shm = File('${targetFile.path}-shm');
      if (await shm.exists()) {
        await shm.delete();
      }

      return SubscriptionListSucceeded(targetFile.path);
    } catch (e) {
      return SubscriptionListFailed(e);
    }
  }
}

class SubscriptionListPicker {
  static Future<({String? path, Uint8List? bytes, String name})?> pick({
    required String dialogTitle,
  }) async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: dialogTitle,
      withData: true,
    );
    if (selected == null || selected.files.isEmpty) {
      return null;
    }
    final source = selected.files.single;
    return (
      path: source.path?.trim(),
      bytes: source.bytes,
      name: source.name.trim().toLowerCase(),
    );
  }
}
