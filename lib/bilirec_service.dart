import 'dart:ffi';
import 'dart:convert';
import 'dart:io';

import 'package:ffi/ffi.dart';

class StartConfig {
  const StartConfig({
    required this.basePath,
    this.port,
    this.host,
    this.frontendUrl,
    this.outputDir,
    this.username,
    this.password,
  });

  final String basePath;
  final int? port;
  final String? host;
  final String? frontendUrl;
  final String? outputDir;
  final String? username;
  final String? password;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'basePath': basePath};
    if (port != null) map['port'] = port;
    if (host != null && host!.isNotEmpty) map['host'] = host;
    if (frontendUrl != null && frontendUrl!.isNotEmpty) {
      map['frontendUrl'] = frontendUrl;
    }
    if (outputDir != null && outputDir!.isNotEmpty) {
      map['outputDir'] = outputDir;
    }
    if (username != null && username!.isNotEmpty) {
      map['username'] = username;
    }
    if (password != null && password!.isNotEmpty) {
      map['password'] = password;
    }
    return map;
  }
}

class BilirecService {
  static late final DynamicLibrary _lib;

  // 定義 C 與 Dart 的函式簽名
  // C 簽名: int Start(char* configJson)
  // Dart FFI: Int32 Function(Pointer<Utf8>)
  static late final int Function(Pointer<Utf8>) _startNative;
  static late final int Function() _stopNative;

  static bool _isInitialized = false;

  /// 初始化並載入 .so 檔案
  static void initialize() {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libbilirec.so');
    } else {
      throw UnsupportedError('此核心目前僅支援 Android 平台');
    }

    // 綁定 Start 函式
    _startNative = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('Start')
        .asFunction<int Function(Pointer<Utf8>)>();

    // 綁定 Stop 函式
    _stopNative = _lib
        .lookup<NativeFunction<Int32 Function()>>('Stop')
        .asFunction<int Function()>();

    _isInitialized = true;
  }

  /// 呼叫 Go 的 Start(configJson)
  static int start(StartConfig config) {
    _checkInitialized();
    final configJson = jsonEncode(config.toJson());
    final configPtr = configJson.toNativeUtf8();
    try {
      return _startNative(configPtr);
    } finally {
      malloc.free(configPtr);
    }
  }

  /// 呼叫 Go 的 Stop()
  static int stop() {
    _checkInitialized();
    return _stopNative();
  }

  static void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError('BilirecService 尚未初始化，請先呼叫 initialize()');
    }
  }
}