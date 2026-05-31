import 'dart:async';

import 'package:bilirec/shared/debugger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

class NetworkLockService {
  static const _channel = MethodChannel('org.bilirec.bilirec/network_lock');
  final Connectivity _connectivity = Connectivity();

  bool _isProcessing = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // 初始化並開始監聽網路變化
  Future<bool> start() async {
    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // 簡單起見，取第一個結果
      final result = results.first;
      _applyLockBasedOnResult(result);
    });

    // 首次啟動時執行一次當前狀態檢測
    final results = await _connectivity.checkConnectivity();
    return _applyLockBasedOnResult(results.first);
  }

  Future<bool> _applyLockBasedOnResult(ConnectivityResult result) async {
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      final String method;
      final Map<String, String>? args;

      if (result == ConnectivityResult.wifi) {
        method = 'enable';
        args = {'type': 'wifi'};
      } else if (result == ConnectivityResult.mobile) {
        method = 'enable';
        args = {'type': 'cellular'};
      } else {
        method = 'disable';
        args = null;
      }

      final success = await _channel.invokeMethod(method, args);
      return success as bool;
    } on PlatformException catch (e) {
      debugLog("Platform Error: ${e.code}, ${e.message}");
      return false;
    } catch (e) {
      debugLog("Unexpected Error: $e");
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  Future<NetworkLockStatus?> getStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('status');
      return result != null ? NetworkLockStatus.fromMap(result) : null;
    } on PlatformException catch (e) {
      debugLog("Platform Error: ${e.code}, ${e.message}");
      return null;
    } catch (e) {
      debugLog("Unexpected Error: $e");
      return null;
    }
  }

  Future<bool> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _isProcessing = true;
    try {
      final result = await _channel.invokeMethod('disable');
      return result as bool;
    } on PlatformException catch (e) {
      debugLog("Platform Error: ${e.code}, ${e.message}");
      return false;
    } catch (e) {
      debugLog("Unexpected Error: $e");
      return false;
    } finally {
      _isProcessing = false;
    }
  }
}

class NetworkLockStatus {
  final bool isWifiLocked;
  final bool isCellularLocked;

  NetworkLockStatus({
    required this.isWifiLocked,
    required this.isCellularLocked,
  });

  // 💡 核心：手動解析對應的欄位，並處理好 Null 安全與型別轉換
  factory NetworkLockStatus.fromMap(Map<dynamic, dynamic> map) {
    return NetworkLockStatus(
      isWifiLocked: map['wifiLocked'] as bool? ?? false,
      isCellularLocked: map['cellularLocked'] as bool? ?? false,
    );
  }
}