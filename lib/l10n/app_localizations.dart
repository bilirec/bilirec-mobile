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
      'controlCenterTitle': 'Bilirec 服務控制中心',
      'initializing': '初始化中...',
      'backendNotRunning': 'Bilirec 系統服務未啟動',
      'backendRunning': 'Bilirec 系統服務運行中',
      'serviceStartFailedNativeExit': 'Bilirec 系統服務啟動失敗，請再試一次',
      'serviceStartFailedWithCode': 'Bilirec 系統服務啟動失敗（錯誤代碼：{code}）',
      'backendStopped': 'Bilirec 系統服務已停止',
      'backendNoResponse': 'Bilirec 系統服務暫時無回應，可能已被系統終止',
      'notificationHeartbeatReceived': '已收到通知更新',
      'serviceStoppedFromNotification': '已透過通知停止服務',
      'cannotOpenFrontendBrowser': '無法打開錄製管理程式',
      'ppkKilledTitle': 'Bilirec 系統服務已被終止',
      'ppkKilledBody': '偵測到系統服務被中斷，請重新啟動，並確認已關閉省電限制。',
      'selectOutputPath': '選擇錄製輸出路徑',
      'pathUnsupported': '此路徑目前不可用，請改選以下位置：{paths}',
      'pathAutoSaved': '已自動儲存路徑',
      'batteryUnrestrictedReady': '已設為不受電池限制，系統服務較不易被終止',
      'batteryDialogTitle': '需要關閉省電限制',
      'batteryDialogContent': '請將 Bilirec 設為不受電池限制，否則系統服務可能被關閉。\n\n完成後請回到 App。',
      'goToSettings': '前往設定',
      'androidOnly': '目前只支援 Android',
      'startingService': '正在啟動 Bilirec 系統服務...',
      'notificationPermissionDenied': '通知權限未開啟，無法啟動系統服務',
      'foregroundStartWaitingCore': 'Bilirec 系統服務已啟動，正在準備中...',
      'foregroundStartFailed': 'Bilirec 系統服務啟動失敗，請再試一次',
      'stopServiceFailed': 'Bilirec 系統服務停止失敗',
      'serviceOperationFailed': '服務操作失敗：{error}',
      'backendHealthy': 'Bilirec 系統服務連線正常',
      'backendUnhealthy': 'Bilirec 系統服務回應異常，請稍後再試',
      'backendNoResponseHint': 'Bilirec 系統服務沒有回應，請確認已啟動',
      'backendCannotConnect': '目前無法連線到 Bilirec 系統服務，請確認已啟動',
      'startingShort': '啟動中...',
      'stop': '停止',
      'start': '啟動',
      'openFrontend': '打開錄製管理程式',
      'checkBackendConnection': '檢查系統服務連線',
      'setOutputPathTitle': '設定錄製輸出路徑',
      'browseAndSetOutputPath': '瀏覽並設定輸出路徑',
      'outputPathUnset': '目前尚未設定輸出路徑（使用預設）',
      'outputPathValue': '輸出路徑：{path}',
      'notificationTitleRunning': 'Bilirec 系統服務運行中',
      'notificationTextRunning': '打開錄製應用程式即可開始錄製',
      'notificationButtonStop': '停止服務',
      'recording': '錄製中',
      'languageTraditional': '繁',
      'languageSimplified': '簡',
      'languageMenuTooltip': '切換語言',
    },
    AppLocaleConfig.simplifiedCode: {
      'controlCenterTitle': 'Bilirec 服务控制中心',
      'initializing': '初始化中...',
      'backendNotRunning': 'Bilirec 系统服务未启动',
      'backendRunning': 'Bilirec 系统服务运行中',
      'serviceStartFailedNativeExit': 'Bilirec 系统服务启动失败，请重试',
      'serviceStartFailedWithCode': 'Bilirec 系统服务启动失败（错误代码：{code}）',
      'backendStopped': 'Bilirec 系统服务已停止',
      'backendNoResponse': 'Bilirec 系统服务暂时无响应，可能已被系统终止',
      'notificationHeartbeatReceived': '已收到通知更新',
      'serviceStoppedFromNotification': '已通过通知停止服务',
      'cannotOpenFrontendBrowser': '无法打开录制管理程序',
      'ppkKilledTitle': 'Bilirec 系统服务已被终止',
      'ppkKilledBody': '检测到系统服务被中断，请重新启动，并确认已关闭省电限制。',
      'selectOutputPath': '选择录制输出路径',
      'pathUnsupported': '此路径暂不可用，请改选以下位置：{paths}',
      'pathAutoSaved': '已自动保存路径',
      'batteryUnrestrictedReady': '已设为不受电池限制，系统服务更不容易被终止',
      'batteryDialogTitle': '需要关闭省电限制',
      'batteryDialogContent': '请将 Bilirec 设为不受电池限制，否则系统服务可能被关闭。\n\n完成后请回到 App。',
      'goToSettings': '前往设置',
      'androidOnly': '目前仅支持 Android',
      'startingService': '正在启动 Bilirec 系统服务...',
      'notificationPermissionDenied': '通知权限未开启，无法启动系统服务',
      'foregroundStartWaitingCore': 'Bilirec 系统服务已启动，正在准备中...',
      'foregroundStartFailed': 'Bilirec 系统服务启动失败，请重试',
      'stopServiceFailed': 'Bilirec 系统服务停止失败',
      'serviceOperationFailed': '服务操作失败：{error}',
      'backendHealthy': 'Bilirec 系统服务连接正常',
      'backendUnhealthy': 'Bilirec 系统服务响应异常，请稍后再试',
      'backendNoResponseHint': 'Bilirec 系统服务没有响应，请确认已启动',
      'backendCannotConnect': '目前无法连接到 Bilirec 系统服务，请确认已启动',
      'startingShort': '启动中...',
      'stop': '停止',
      'start': '启动',
      'openFrontend': '打开录制管理程序',
      'checkBackendConnection': '检查系统服务连接',
      'setOutputPathTitle': '设置录制输出路径',
      'browseAndSetOutputPath': '浏览并设置输出路径',
      'outputPathUnset': '目前尚未设置输出路径（使用默认）',
      'outputPathValue': '输出路径：{path}',
      'notificationTitleRunning': 'Bilirec 系统服务运行中',
      'notificationTextRunning': '打开录制应用程序即可开始录制',
      'notificationButtonStop': '停止服务',
      'recording': '录制中',
      'languageTraditional': '繁',
      'languageSimplified': '简',
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