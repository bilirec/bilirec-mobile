import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'network_lock_method_channel.dart';

abstract class NetworkLockPlatform extends PlatformInterface {
  /// Constructs a NetworkLockPlatform.
  NetworkLockPlatform() : super(token: _token);

  static final Object _token = Object();

  static NetworkLockPlatform _instance = MethodChannelNetworkLock();

  /// The default instance of [NetworkLockPlatform] to use.
  ///
  /// Defaults to [MethodChannelNetworkLock].
  static NetworkLockPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NetworkLockPlatform] when
  /// they register themselves.
  static set instance(NetworkLockPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
