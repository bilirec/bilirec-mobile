
import 'network_lock_platform_interface.dart';

class NetworkLock {
  Future<String?> getPlatformVersion() {
    return NetworkLockPlatform.instance.getPlatformVersion();
  }
}
