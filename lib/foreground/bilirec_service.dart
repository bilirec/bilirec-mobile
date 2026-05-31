import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

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
    this.sseToken,
    this.env,
  });

  final String basePath;
  final int? port;
  final String? host;
  final String? frontendUrl;
  final String? outputDir;
  final String? username;
  final String? password;
  final String? sseToken;
  final Map<String, String>? env;

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
    if (sseToken != null && sseToken!.isNotEmpty) {
      map['sseToken'] = sseToken;
    }
    if (env != null && env!.isNotEmpty) {
      map['env'] = env;
    }
    return map;
  }
}

class BilirecService {
  /// 呼叫 Go 的 Start(configJson)
  static Future<int> start(StartConfig config) async {
    final configJson = jsonEncode(config.toJson());
    return await Isolate.run(() {
      final lib = DynamicLibrary.open('libbilirec.so');
      final startNative = lib
          .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('Start')
          .asFunction<int Function(Pointer<Utf8>)>();
      final configPtr = configJson.toNativeUtf8();
      try {
        return startNative(configPtr);
      } finally {
        malloc.free(configPtr);
      }
    });
  }

  /// 呼叫 Go 的 Stop()
  static Future<int> stop() async {
    return await Isolate.run(() {
      final lib = DynamicLibrary.open('libbilirec.so');
      final stopNative = lib
          .lookup<NativeFunction<Int32 Function()>>('Stop')
          .asFunction<int Function()>();
      return stopNative();
    });
  }
}
