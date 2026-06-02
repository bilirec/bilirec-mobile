import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

class StartConfig {
  const StartConfig({
    required this.basePath,
    this.env,
  });

  final String basePath;
  final Map<String, String>? env;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'basePath': basePath};
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
