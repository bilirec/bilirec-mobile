import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocaleConfig {
  static const String simplifiedCode = 'zh_Hans';
  static const String traditionalCode = 'zh_Hant';

  static const Locale simplifiedLocale = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
    countryCode: 'CN',
  );

  static const Locale traditionalLocale = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'TW',
  );

  static Locale localeForCode(String code) {
    if (code == simplifiedCode) {
      return simplifiedLocale;
    }
    return traditionalLocale;
  }

  static String codeForLocale(Locale locale) {
    if (locale.scriptCode == 'Hans' || locale.countryCode == 'CN') {
      return simplifiedCode;
    }
    return traditionalCode;
  }
}

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    AppLocaleConfig.traditionalLocale,
    AppLocaleConfig.simplifiedLocale,
  ];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations ?? AppLocalizations(AppLocaleConfig.traditionalLocale);
  }

  String tr(String key, {Map<String, String> params = const {}}) {
    final languageCode = AppLocaleConfig.codeForLocale(locale);
    final text = _localizedValues[languageCode]?[key] ?? key;
    if (params.isEmpty) return text;

    var resolved = text;
    params.forEach((paramKey, value) {
      resolved = resolved.replaceAll('{$paramKey}', value);
    });
    return resolved;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    AppLocaleConfig.traditionalCode: {
      'controlCenterTitle': 'Bilirec 後台服務控制中心',
      'initializing': '初始化中...',
      'backendNotRunning': 'Bilirec 後端未運行',
      'backendRunning': 'Bilirec 後端運行中',
      'serviceStartFailedNativeExit': '服務啟動失敗：native 核心返回 exit code 1',
      'serviceStartFailedWithCode': '服務啟動失敗，代碼: {code}',
      'backendStopped': 'Bilirec 後端已停止',
      'backendNoResponse': 'Bilirec 後端無回應（可能被系統終止）',
      'notificationHeartbeatReceived': '已收到通知服務心跳',
      'serviceStoppedFromNotification': '已透過通知停止服務',
      'cannotOpenFrontendBrowser': '無法啟動前端瀏覽器',
      'ppkKilledTitle': 'Bilirec 服務已被系統終止',
      'ppkKilledBody': '偵測到前景服務異常中斷（疑似 PPK），請重新啟動並確認電池無限制。',
      'selectOutputPath': '選擇錄製輸出路徑',
      'pathUnsupported': '路徑不支援前景服務，請選擇以下路徑底下: {paths}',
      'pathAutoSaved': '已自動儲存路徑',
      'batteryUnrestrictedReady': '已設定電池無限制，bilirec 更不容易被系統終止',
      'batteryDialogTitle': '需要電池無限制',
      'batteryDialogContent': '請將 bilirec 設為電池無限制，否則後台服務可能被系統關閉。\n\n完成後請回到 App。',
      'goToSettings': '前往設定',
      'androidOnly': '目前僅支援 Android 前景服務',
      'startingService': '正在啟動服務...',
      'notificationPermissionDenied': '通知權限未開啟，無法啟動前景服務',
      'foregroundStartWaitingCore': '前景服務已啟動，等待核心回報...',
      'foregroundStartFailed': '前景服務啟動失敗',
      'stopServiceFailed': '停止服務失敗',
      'serviceOperationFailed': '服務操作失敗: {error}',
      'backendHealthy': '後端服務正常，可以連線',
      'backendUnhealthy': '後端服務回應異常，請稍後再試',
      'backendNoResponseHint': '後端服務無回應，請確認服務是否已啟動',
      'backendCannotConnect': '無法連線至後端服務，請確認服務是否已啟動',
      'startingShort': '啟動中...',
      'stop': '停止',
      'start': '啟動',
      'openFrontend': '啟動前端',
      'checkBackendConnection': '檢測後端連線',
      'setOutputPathTitle': '設置錄製輸出路徑',
      'browseAndSetOutputPath': '瀏覽並設置輸出路徑',
      'outputPathUnset': '目前尚未設置輸出路徑（使用預設）',
      'outputPathValue': '輸出路徑: {path}',
      'notificationTitleRunning': 'Bilirec 後端正在運行',
      'notificationTextRunning': '後台錄製服務運行中',
      'notificationButtonStop': '停止服務',
      'languageTraditional': '繁中',
      'languageSimplified': '簡中',
      'languageMenuTooltip': '切換語言',
    },
    AppLocaleConfig.simplifiedCode: {
      'controlCenterTitle': 'Bilirec 后台服务控制中心',
      'initializing': '初始化中...',
      'backendNotRunning': 'Bilirec 后端未运行',
      'backendRunning': 'Bilirec 后端运行中',
      'serviceStartFailedNativeExit': '服务启动失败：native 核心返回 exit code 1',
      'serviceStartFailedWithCode': '服务启动失败，代码: {code}',
      'backendStopped': 'Bilirec 后端已停止',
      'backendNoResponse': 'Bilirec 后端无响应（可能被系统终止）',
      'notificationHeartbeatReceived': '已收到通知服务心跳',
      'serviceStoppedFromNotification': '已通过通知停止服务',
      'cannotOpenFrontendBrowser': '无法启动前端浏览器',
      'ppkKilledTitle': 'Bilirec 服务已被系统终止',
      'ppkKilledBody': '检测到前景服务异常中断（疑似 PPK），请重新启动并确认电池无限制。',
      'selectOutputPath': '选择录制输出路径',
      'pathUnsupported': '路径不支持前景服务，请选择以下路径下: {paths}',
      'pathAutoSaved': '已自动保存路径',
      'batteryUnrestrictedReady': '已设置电池无限制，bilirec 更不容易被系统终止',
      'batteryDialogTitle': '需要电池无限制',
      'batteryDialogContent': '请将 bilirec 设为电池无限制，否则后台服务可能被系统关闭。\n\n完成后请回到 App。',
      'goToSettings': '前往设置',
      'androidOnly': '目前仅支持 Android 前景服务',
      'startingService': '正在启动服务...',
      'notificationPermissionDenied': '通知权限未开启，无法启动前景服务',
      'foregroundStartWaitingCore': '前景服务已启动，等待核心回报...',
      'foregroundStartFailed': '前景服务启动失败',
      'stopServiceFailed': '停止服务失败',
      'serviceOperationFailed': '服务操作失败: {error}',
      'backendHealthy': '后端服务正常，可以连接',
      'backendUnhealthy': '后端服务响应异常，请稍后再试',
      'backendNoResponseHint': '后端服务无响应，请确认服务是否已启动',
      'backendCannotConnect': '无法连接至后端服务，请确认服务是否已启动',
      'startingShort': '启动中...',
      'stop': '停止',
      'start': '启动',
      'openFrontend': '启动前端',
      'checkBackendConnection': '检测后端连接',
      'setOutputPathTitle': '设置录制输出路径',
      'browseAndSetOutputPath': '浏览并设置输出路径',
      'outputPathUnset': '目前尚未设置输出路径（使用默认）',
      'outputPathValue': '输出路径: {path}',
      'notificationTitleRunning': 'Bilirec 后端正在运行',
      'notificationTextRunning': '后台录制服务运行中',
      'notificationButtonStop': '停止服务',
      'languageTraditional': '繁中',
      'languageSimplified': '简中',
      'languageMenuTooltip': '切换语言',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

