import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_stream/saf_stream_platform_interface.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

class SafExportGateway {
  SafExportGateway({
    SafUtil? safUtil,
    SafStream? safStream,
    DeviceInfoPlugin? deviceInfo,
  })  : _safUtil = safUtil ?? SafUtil(),
        _safStream = safStream ?? SafStream(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final SafUtil _safUtil;
  final SafStream _safStream;
  final DeviceInfoPlugin _deviceInfo;

  // Keep Android 10 on legacy flow to avoid behavior changes in existing tests and devices.
  Future<bool> shouldUseSafExport() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final sdkInt = (await _deviceInfo.androidInfo).version.sdkInt;
      return sdkInt >= 30;
    } catch (_) {
      return false;
    }
  }

  Future<SafDocumentFile?> pickDirectoryForWrite() {
    return _safUtil.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
  }

  Future<SafNewFile> writeMergedTextFileFromLocalFiles({
    required String treeUri,
    required String fileName,
    required List<File> sourceFiles,
    String mimeType = 'text/plain',
  }) async {
    final writeInfo = await _safStream.startWriteStream(
      treeUri,
      fileName,
      mimeType,
      overwrite: false,
      append: false,
    );

    var closed = false;
    try {
      for (final file in sourceFiles) {
        await for (final chunk in file.openRead()) {
          if (chunk.isEmpty) {
            continue;
          }
          await _safStream.writeChunk(
            writeInfo.session,
            Uint8List.fromList(chunk),
          );
        }

        await _safStream.writeChunk(writeInfo.session, _lineBreakBytes);
      }

      await _safStream.endWriteStream(writeInfo.session);
      closed = true;
      return writeInfo.fileResult;
    } finally {
      if (!closed) {
        try {
          await _safStream.endWriteStream(writeInfo.session);
        } catch (_) {
          // Best-effort close to prevent session leaks on partial writes.
        }
      }
    }
  }

  Future<SafNewFile> copyLocalFileToDirectory({
    required String sourcePath,
    required String treeUri,
    required String fileName,
    required String mimeType,
  }) {
    return _safStream.pasteLocalFile(
      sourcePath,
      treeUri,
      fileName,
      mimeType,
      overwrite: false,
      append: false,
    );
  }

  static final Uint8List _lineBreakBytes = Uint8List.fromList(<int>[0x0A]);
}
