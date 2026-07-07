import 'package:bilirec/shared/debugger.dart';
import 'package:bilirec/shared/saf_export_gateway.dart';
import 'package:file_picker/file_picker.dart';

enum FileExportLocationType { safUri, filePath }

class FileExportResult {
  const FileExportResult._({
    required this.location,
    required this.locationType,
  });

  final String location;
  final FileExportLocationType locationType;

  bool get usedSaf => locationType == FileExportLocationType.safUri;
}

class FileExporter {
  FileExporter({
    SafExportGateway? safExportGateway,
    FilePicker? filePicker,
  })  : _safExportGateway = safExportGateway ?? SafExportGateway(),
        _filePicker = filePicker;

  final SafExportGateway _safExportGateway;
  final FilePicker? _filePicker;

  FilePicker get _effectiveFilePicker => _filePicker ?? FilePicker.platform;

  Future<FileExportResult?> exportWithSafFallback({
    required String dialogTitle,
    required Future<String> Function(String treeUri) writeWithSaf,
    required Future<String> Function(String directoryPath) writeWithPath,
    void Function(Object error)? onSafFailed,
  }) async {
    final shouldUseSaf = await _safExportGateway.shouldUseSafExport();
    debugLog(
      'file_exporter: start export strategy, preferSaf=$shouldUseSaf, title=$dialogTitle',
    );

    if (shouldUseSaf) {
      try {
        debugLog('file_exporter: opening SAF directory picker');
        final pickedDir = await _safExportGateway.pickDirectoryForWrite();
        if (pickedDir == null) {
          debugLog('file_exporter: user cancelled SAF directory picker');
          return null;
        }

        debugLog('file_exporter: SAF directory selected uri=${pickedDir.uri}');
        final safLocation = await writeWithSaf(pickedDir.uri);
        debugLog('file_exporter: SAF export success uri=$safLocation');
        return FileExportResult._(
          location: safLocation,
          locationType: FileExportLocationType.safUri,
        );
      } catch (e) {
        debugLog('file_exporter: SAF export failed, fallback to file path: $e');
        onSafFailed?.call(e);
      }
    } else {
      debugLog('file_exporter: SAF disabled for current platform/version');
    }

    debugLog('file_exporter: opening legacy directory picker');
    final selectedDir =
        await _effectiveFilePicker.getDirectoryPath(dialogTitle: dialogTitle);
    if (selectedDir == null || selectedDir.trim().isEmpty) {
      debugLog('file_exporter: user cancelled legacy directory picker');
      return null;
    }

    debugLog('file_exporter: legacy directory selected path=${selectedDir.trim()}');
    final pathLocation = await writeWithPath(selectedDir.trim());
    debugLog('file_exporter: legacy path export success path=$pathLocation');
    return FileExportResult._(
      location: pathLocation,
      locationType: FileExportLocationType.filePath,
    );
  }
}

