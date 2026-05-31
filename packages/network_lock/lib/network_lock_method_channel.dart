import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'network_lock_platform_interface.dart';

/// An implementation of [NetworkLockPlatform] that uses method channels.
class MethodChannelNetworkLock extends NetworkLockPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('org.bilirec.bilirec/network_lock');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
