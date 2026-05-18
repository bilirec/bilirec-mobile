import 'dart:ffi';
import 'dart:io';

class BilirecService {
  static late final DynamicLibrary _lib;

  // 定義 C 語言與 Dart 語言的函式簽名
  // C 簽名: int Start(void) -> Int32 Function()
  // Dart 簽名: int Start()   -> int Function()
  static late final int Function() _startNative;
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
        .lookup<NativeFunction<Int32 Function()>>('Start')
        .asFunction<int Function()>();

    // 綁定 Stop 函式
    _stopNative = _lib
        .lookup<NativeFunction<Int32 Function()>>('Stop')
        .asFunction<int Function()>();

    _isInitialized = true;
  }

  /// 呼叫 Go 的 Start()
  static int start() {
    _checkInitialized();
    return _startNative();
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