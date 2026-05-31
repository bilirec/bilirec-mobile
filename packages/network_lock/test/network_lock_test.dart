import 'package:flutter_test/flutter_test.dart';
import 'package:network_lock/network_lock.dart';
import 'package:network_lock/network_lock_platform_interface.dart';
import 'package:network_lock/network_lock_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNetworkLockPlatform
    with MockPlatformInterfaceMixin
    implements NetworkLockPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NetworkLockPlatform initialPlatform = NetworkLockPlatform.instance;

  test('$MethodChannelNetworkLock is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNetworkLock>());
  });

  test('getPlatformVersion', () async {
    NetworkLock networkLockPlugin = NetworkLock();
    MockNetworkLockPlatform fakePlatform = MockNetworkLockPlatform();
    NetworkLockPlatform.instance = fakePlatform;

    expect(await networkLockPlugin.getPlatformVersion(), '42');
  });
}
