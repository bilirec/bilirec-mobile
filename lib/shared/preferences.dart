

import 'package:shared_preferences/shared_preferences.dart';


const String _expectedRunningKey = 'expected_service_running';
const String _outputDirKey = 'output_dir';
const String _stoppedByUserKey = 'stopped_by_user';
const String _localeCodeKey = 'locale_code';
const String _enableSsePushKey = 'enable_sse_push';
const String _enableAntiSleepKey = 'enable_antisleep';

const String coreRunningKey = 'core_running';

sealed class Preferences {

  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  static Future<void> setExpectedRunning(bool value) async {
    final prefs = _prefs;
    await prefs.setBool(_expectedRunningKey, value);
  }

  static Future<bool> getExpectedRunning() async {
    final prefs = _prefs;
    return await prefs.getBool(_expectedRunningKey) ?? false;
  }

  static Future<void> setStoppedByUser(bool value) async {
    final prefs = _prefs;
    await prefs.setBool(_stoppedByUserKey, value);
  }

  static Future<bool> getStoppedByUser() async {
    final prefs = _prefs;
    return await prefs.getBool(_stoppedByUserKey) ?? false;
  }

  static Future<void> setLocaleCode(String? code) async {
    final prefs = _prefs;
    if (code == null) {
      await prefs.remove(_localeCodeKey);
    } else {
      await prefs.setString(_localeCodeKey, code);
    }
  }

  static Future<String?> getLocaleCode() async {
    final prefs = _prefs;
    return prefs.getString(_localeCodeKey);
  }

  static Future<void> setOutputDir(String? path) async {
    final prefs = _prefs;
    if (path == null) {
      await prefs.remove(_outputDirKey);
    } else {
      await prefs.setString(_outputDirKey, path);
    }
  }

  static Future<String?> getOutputDir() async {
    final prefs = _prefs;
    return prefs.getString(_outputDirKey);
  }

  static Future<void> setEnableSsePush(bool value) async {
    final prefs = _prefs;
    await prefs.setBool(_enableSsePushKey, value);
  }

  static Future<bool> getEnableSsePush() async {
    final prefs = _prefs;
    return await prefs.getBool(_enableSsePushKey) ?? false;
  }

  static Future<void> setEnableAntiSleep(bool value) async {
    final prefs = _prefs;
    await prefs.setBool(_enableAntiSleepKey, value);
  }

  static Future<bool> getEnableAntiSleep() async {
    final prefs = _prefs;
    return await prefs.getBool(_enableAntiSleepKey) ?? false;
  }

}