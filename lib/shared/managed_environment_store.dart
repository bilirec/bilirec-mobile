import 'package:bilirec/shared/preferences.dart';

class ManagedEnvironmentStore {
  Future<void> _queue = Future<void>.value();

  Future<void> update(
    Map<String, String> Function(Map<String, String> current) transform,
  ) {
    final next = _queue.then((_) async {
      final latest = await Preferences.getManagedEnvironmentSettings();
      final updated = transform(<String, String>{...latest});
      await Preferences.setManagedEnvironmentSettings(updated);
    });
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> set(String key, String value) {
    return update((current) {
      current[key] = value;
      return current;
    });
  }
}
