import 'dart:io';

import 'package:flutter/cupertino.dart';

/// 專注於 BiliRec 本進程資源佔用計算的通用工具（純 Dart 實現）
class ResourceMonitor {
  int _lastAppCpuTime = 0;
  int _lastSystemTime = 0;

  ResourceMonitor() {
    _resetAnchor();
  }

  void _resetAnchor() {
    _lastAppCpuTime = _getPureCpuTimeTicks();
    _lastSystemTime = DateTime.now().millisecondsSinceEpoch;
  }

  (int, int) getUsage() {
    // 1. RAM 讀取 currentRss 安全無虞，繼續保留
    // final int ramUsage = (ProcessInfo.currentRss / (1024 * 1024)).round();
    final int ramUsage = _getExactPrivateRam();

    // 2. 安全計算 CPU
    final int cpuUsage = _calculatePureCpuUsage();
    return (cpuUsage, ramUsage);
  }

  int _getExactPrivateRam() {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        final file = File('/proc/self/status');
        if (file.existsSync()) {
          final lines = file.readAsLinesSync();
          int rssAnon = 0; // 匿名記憶體（真正屬於你的記憶體）

          for (var line in lines) {
            // 👑 RssAnon 是 Linux 核心統計該進程真正獨佔、無法被其他 App 共用的實體記憶體
            if (line.startsWith('RssAnon:')) {
              final RegExp regExp = RegExp(r'\d+');
              final match = regExp.stringMatch(line);
              if (match != null) {
                rssAnon = int.parse(match);
                break;
              }
            }
          }

          if (rssAnon > 0) {
            return (rssAnon / 1024).round(); // kB 轉成 MB
          }
        }
      }
    } catch (_) {
      debugPrint('無法讀取 /proc/self/status，改用 fallback 方法');
    }

    // 如果拿不到，再用 currentRss 兜底
    return (ProcessInfo.currentRss / (1024 * 1024)).round();
  }

  int _calculatePureCpuUsage() {
    final int currentAppTime = _getPureCpuTimeTicks();
    final int currentSystemTime = DateTime.now().millisecondsSinceEpoch;

    final int appTimeDelta = currentAppTime - _lastAppCpuTime;
    final int timeDeltaMs = currentSystemTime - _lastSystemTime;

    _lastAppCpuTime = currentAppTime;
    _lastSystemTime = currentSystemTime;

    if (timeDeltaMs <= 0 || appTimeDelta <= 0) return 1; // 兜底避免除以 0

    // 算本進程佔用單核心的百分比
    double cpuPercent = (appTimeDelta / timeDeltaMs) * 100;

    // 💥 修正：不要呼叫 Platform.numberOfProcessors！
    // 很多手機的 ROM 在讀取這個屬性時，底層會去踩 /sys/devices/system/cpu 或者是 /sys/module/metis
    // 這在現代 Android 會直接觸發 SELinux AVC Denied！
    // 我們直接寫死除以一個常規核心數（例如 8 核），或者乾脆不做跨核平均，直接顯示單核換算值。
    cpuPercent = cpuPercent / 8;

    return cpuPercent.round().clamp(0, 100);
  }

  int _getPureCpuTimeTicks() {
    // 💥 終極防禦：用最高級別的 try-catch 包裹，確保不論發生甚麼 SELinux 錯誤，絕對不卡死進程！
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        // 唯有 /proc/self/stat 是 Linux 核心承諾 100% 豁免 SELinux 的安全通路
        final file = File('/proc/self/stat');
        if (file.existsSync()) {
          final String stat = file.readAsStringSync();
          final List<String> parts = stat.split(' ');
          if (parts.length > 14) {
            int utime = int.parse(parts[13]);
            int stime = int.parse(parts[14]);
            return (utime + stime) * 10;
          }
        }
      }
    } catch (e) {
      // 就算被系統攔截，也默默吞掉，返回 0，絕對不讓 UI 線程崩潰
    }
    return 0;
  }
}