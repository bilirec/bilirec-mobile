

import 'package:shared_preferences/shared_preferences.dart';


const String _expectedRunningKey = 'expected_service_running';
const String _outputDirKey = 'output_dir';
const String _stoppedByUserKey = 'stopped_by_user';
const String _localeCodeKey = 'locale_code';
const String _enableSsePushKey = 'enable_sse_push';

const String coreRunningKey = 'core_running';

sealed class Preferences {

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> setExpectedRunning(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_expectedRunningKey, value);
  }

  static Future<bool> getExpectedRunning() async {
    final prefs = await _prefs;
    return prefs.getBool(_expectedRunningKey) ?? false;
  }

  static Future<void> setStoppedByUser(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_stoppedByUserKey, value);
  }

  static Future<bool> getStoppedByUser() async {
    final prefs = await _prefs;
    return prefs.getBool(_stoppedByUserKey) ?? false;
  }

  static Future<void> setLocaleCode(String? code) async {
    final prefs = await _prefs;
    if (code == null) {
      await prefs.remove(_localeCodeKey);
    } else {
      await prefs.setString(_localeCodeKey, code);
    }
  }

  static Future<String?> getLocaleCode() async {
    final prefs = await _prefs;
    return prefs.getString(_localeCodeKey);
  }

  static Future<void> setOutputDir(String? path) async {
    final prefs = await _prefs;
    if (path == null) {
      await prefs.remove(_outputDirKey);
    } else {
      await prefs.setString(_outputDirKey, path);
    }
  }

  static Future<String?> getOutputDir() async {
    final prefs = await _prefs;
    return prefs.getString(_outputDirKey);
  }

  static Future<void> setEnableSsePush(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_enableSsePushKey, value);
  }

  static Future<bool> getEnableSsePush() async {
    final prefs = await _prefs;
    return prefs.getBool(_enableSsePushKey) ?? false;
  }

}