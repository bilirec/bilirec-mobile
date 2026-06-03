import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _logTag = 'LIBRARY_LOAD_TEST';

void _log(String message) {
  final timestamp = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$_logTag][$timestamp] $message');
}

// Local test only, will not include in CI to avoid false positives due to environment differences
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Native Library Integration Tests', () {
    testWidgets('在虚拟设备上加载 libbilirec.so', (tester) async {
      _log('========================================');
      _log('开始动态库加载测试');
      _log('========================================');

      _log('平台信息:');
      _log('  操作系统: ${Platform.operatingSystem}');
      _log('  版本: ${Platform.operatingSystemVersion}');
      _log('  ABI: ${Abi.current()}');

      if (!Platform.isAndroid) {
        _log('⚠️ 当前平台不是 Android，跳过测试');
        markTestSkipped('只在 Android 上运行');
        return;
      }

      _log('');
      _log('尝试加载主动态库...');

      DynamicLibrary? lib;
      String? loadError;
      bool loadSuccess = false;

      // 主加载尝试
      try {
        _log('📦 调用 DynamicLibrary.open("libbilirec.so")...');
        lib = DynamicLibrary.open('libbilirec.so');
        loadSuccess = true;
        _log('✅ 成功加载 libbilirec.so');
      } catch (e, stackTrace) {
        loadError = e.toString();
        _log('❌ 加载失败');
        _log('错误类型: ${e.runtimeType}');
        _log('错误信息: $e');
        _log('堆栈跟踪:');
        for (final line in stackTrace.toString().split('\n').take(10)) {
          _log('  $line');
        }
      }

      // 如果主加载失败，尝试其他路径
      if (!loadSuccess) {
        _log('');
        _log('🔍 尝试备用路径...');

        final alternativePaths = [
          'libbibirec.so', // 拼写错误检测
          '/data/local/tmp/libbilirec.so',
        ];

        for (final path in alternativePaths) {
          try {
            _log('   尝试: $path');
            lib = DynamicLibrary.open(path);
            loadSuccess = true;
            _log('   ✅ 从 $path 成功加载！');
            break;
          } catch (e) {
            _log('   ❌ 失败: ${e.toString().split('\n').first}');
          }
        }
      }

      // 打印诊断信息
      if (!loadSuccess) {
        _log('');
        _log('💥 所有加载尝试都失败');
        _log('');
        _log('📋 可能的原因:');
        _log('   1. libbilirec.so 没有打包到 APK');
        _log('   2. 文件在错误的 jniLibs 目录');
        _log('   3. ABI 不匹配 (期望: ${Abi.current()})');
        _log('   4. 缺少依赖的 .so 文件');
        _log('   5. 权限问题');
        _log('');
        _log('🔧 调试步骤:');
        _log('   1. 运行: adb shell pm path org.bilirec.bilirec');
        _log('   2. 运行: adb shell unzip -l <apk路径> | grep libbilirec');
        _log('   3. 运行: adb shell ls -la /data/app/*/lib/${Abi.current().toString().split('.').last}/');
        _log('   4. 检查 android/app/src/main/jniLibs/ 目录结构');
        _log('');

        expect(loadSuccess, isTrue, reason: '无法加载 libbilirec.so: $loadError');
        return;
      }

      // 成功加载后，检查符号
      _log('');
      _log('🔍 检查导出的符号...');

      final symbolsToCheck = <String>['Start', 'Stop'];

      final results = <String, bool>{};

      for (final name in symbolsToCheck) {
        try {
          final ptr = lib!.lookup<NativeFunction<Void Function()>>(name);
          _log('   ✅ $name: 找到 (地址: $ptr)');
          results[name] = true;
        } catch (e) {
          _log('   ❌ $name: 找不到');
          _log('      ${e.toString().split('\n').first}');
          results[name] = false;
        }
      }

      _log('');
      _log('📊 符号检查摘要:');
      final found = results.values.where((v) => v).length;
      final total = results.length;
      _log('   找到: $found/$total');

      if (found < total) {
        _log('   ⚠️ 缺失的符号:');
        results.forEach((name, found) {
          if (!found) {
            _log('      - $name');
          }
        });
        _log('');
        _log('💡 这可能导致运行时调用失败');
      }

      // 检查 FFmpeg 相关
      _log('');
      _log('🔍 检查 FFmpeg 库...');

      final ffmpegLibs = ['libavutil.so', 'libffmpegkit.so'];
      var ffmpegFound = 0;

      for (final libName in ffmpegLibs) {
        try {
          DynamicLibrary.open(libName);
          _log('   ✅ $libName 可加载');
          ffmpegFound++;
        } catch (e) {
          _log('   ⚠️ $libName 不可加载: ${e.toString().split('\n').first}');
        }
      }

      _log('   FFmpeg 库: $ffmpegFound/${ffmpegLibs.length} 可用');

      if (ffmpegFound == 0) {
        _log('   💡 可能静态链接到 libbilirec.so 或不需要');
      }

      _log('');
      _log('========================================');
      _log('测试完成');
      _log('========================================');

      // 确保主库和核心符号都正常
      expect(loadSuccess, isTrue, reason: '动态库应该能加载');
      expect(results['Start'], isTrue, reason: 'Start 符号应该存在');
      expect(results['Stop'], isTrue, reason: 'Stop 符号应该存在');
    });

    testWidgets('测试实际调用 Start 和 Stop（不启动服务）', (tester) async {
      _log('========================================');
      _log('测试符号调用（空配置）');
      _log('========================================');

      if (!Platform.isAndroid) {
        _log('⚠️ 跳过测试：非 Android 平台');
        markTestSkipped('只在 Android 上运行');
        return;
      }

      DynamicLibrary? lib;

      try {
        lib = DynamicLibrary.open('libbilirec.so');
        _log('✅ 动态库已加载');
      } catch (e) {
        _log('❌ 无法加载动态库: $e');
        fail('无法加载 libbilirec.so: $e');
      }

      // 测试 Stop（应该是安全的，即使服务没启动）
      try {
        _log('🔍 查找 Stop 符号...');
        final stopNative = lib!
            .lookup<NativeFunction<Int32 Function()>>('Stop')
            .asFunction<int Function()>();

        _log('📞 调用 Stop()...');
        final result = stopNative();
        _log('✅ Stop() 返回: $result');

        // Stop 在服务未运行时返回非 0 是正常的
        _log('   (未启动服务时返回非零值是预期行为)');
      } catch (e, stackTrace) {
        _log('❌ 调用 Stop 失败: $e');
        _log('堆栈:');
        for (final line in stackTrace.toString().split('\n').take(5)) {
          _log('  $line');
        }

        // Stop 调用失败是严重问题
        fail('Stop 符号调用失败: $e');
      }

      _log('');
      _log('========================================');
      _log('符号调用测试完成');
      _log('========================================');
    });
  });
}

