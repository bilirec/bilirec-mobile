import 'package:shared_preferences/shared_preferences.dart';

const String _intendedRunningKey = 'unexpected_stop.intended_running';
const String _lastStartIdKey = 'unexpected_stop.last_start_id';
const String _stoppedByUserKey = 'unexpected_stop.stopped_by_user';
const String _legacyStoppedByUserKey = 'stopped_by_user';
const String _promptMutedKey = 'unexpected_stop.prompt_muted';
const String _promptConsumedStartIdKey =
    'unexpected_stop.prompt_consumed_start_id';
const String _lastBootIdKey = 'unexpected_stop.last_boot_id';

class UnexpectedStopSnapshot {
  const UnexpectedStopSnapshot({
    required this.intendedRunning,
    required this.stoppedByUser,
    required this.promptMuted,
    required this.lastStartId,
    required this.consumedStartId,
    required this.lastBootId,
  });

  final bool intendedRunning;
  final bool stoppedByUser;
  final bool promptMuted;
  final int? lastStartId;
  final int? consumedStartId;
  final String? lastBootId;
}

sealed class UnexpectedStopPreferences {
  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  static Future<void> setIntendedRunning(bool value) async {
    await _prefs.setBool(_intendedRunningKey, value);
  }

  static Future<bool> getIntendedRunning() async {
    return await _prefs.getBool(_intendedRunningKey) ?? false;
  }

  static Future<void> setLastBootId(String value) async {
    await _prefs.setString(_lastBootIdKey, value);
  }

  static Future<String?> getLastBootId() async {
    return _prefs.getString(_lastBootIdKey);
  }

  static Future<void> setLastStartId(int value) async {
    await _prefs.setInt(_lastStartIdKey, value);
  }

  static Future<int?> getLastStartId() async {
    return _prefs.getInt(_lastStartIdKey);
  }

  static Future<void> setStoppedByUser(bool value) async {
    await _prefs.setBool(_stoppedByUserKey, value);
    await _prefs.remove(_legacyStoppedByUserKey);
  }

  static Future<bool> getStoppedByUser() async {
    final current = await _prefs.getBool(_stoppedByUserKey);
    if (current != null) {
      return current;
    }
    final legacy = await _prefs.getBool(_legacyStoppedByUserKey);
    if (legacy == null) {
      return false;
    }
    await setStoppedByUser(legacy);
    return legacy;
  }

  static Future<void> setPromptMuted(bool value) async {
    await _prefs.setBool(_promptMutedKey, value);
  }

  static Future<bool> getPromptMuted() async {
    return await _prefs.getBool(_promptMutedKey) ?? false;
  }

  static Future<void> setPromptConsumedStartId(int value) async {
    await _prefs.setInt(_promptConsumedStartIdKey, value);
  }

  static Future<int?> getPromptConsumedStartId() async {
    return _prefs.getInt(_promptConsumedStartIdKey);
  }

  static Future<UnexpectedStopSnapshot> loadSnapshot() async {
    return UnexpectedStopSnapshot(
      intendedRunning: await getIntendedRunning(),
      stoppedByUser: await getStoppedByUser(),
      promptMuted: await getPromptMuted(),
      lastStartId: await getLastStartId(),
      consumedStartId: await getPromptConsumedStartId(),
      lastBootId: await getLastBootId(),
    );
  }

  static Future<void> markServiceStarted({String? bootId}) async {
    await setStoppedByUser(false);
    await setIntendedRunning(true);
    await recordBootId(bootId);
    await setLastStartId(DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> recordBootId(String? bootId) async {
    if (bootId != null && bootId.isNotEmpty) {
      await setLastBootId(bootId);
    }
  }

  static Future<void> markStoppedByUser() async {
    await setStoppedByUser(true);
    await setIntendedRunning(false);
  }

  static Future<void> restoreAfterFailedStop() async {
    await setStoppedByUser(false);
    await setIntendedRunning(true);
  }

  static Future<void> consumePrompt() async {
    final startId = await getLastStartId();
    if (startId == null) {
      return;
    }
    await setPromptConsumedStartId(startId);
  }
}
