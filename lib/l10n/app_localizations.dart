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
      'backendNoResponse': 'Bilirec 系統服務沒有回應，請稍後再試',
      'cannotOpenFrontendBrowser': '無法打開錄製管理程式',
      'ppkKilledTitle': 'Bilirec 系統服務已被終止',
      'ppkKilledBody': '偵測到系統服務被中斷，請重新啟動，並確認已關閉省電限制。',
      'selectOutputPath': '選擇錄製輸出路徑',
      'batteryDialogTitle': '需要關閉省電限制',
      'batteryDialogContent': '請將 Bilirec 設為不受電池限制，否則系統服務可能被關閉。\n\n完成後請回到 App。',
      'goToSettings': '前往設定',
      'androidOnly': '目前只支援 Android',
      'startingService': '正在啟動 Bilirec 系統服務...',
      'notificationPermissionDenied': '通知權限未開啟，無法啟動系統服務',
      'foregroundStartWaitingCore': 'Bilirec 系統服務已啟動，正在準備中...',
      'foregroundStopWaitingCore': 'Bilirec 系統服務已停止，正在等待退出...',
      'foregroundStartFailed': 'Bilirec 系統服務啟動失敗，請再試一次',
      'stopServiceFailed': 'Bilirec 系統服務停止失敗',
      'serviceOperationFailed': '服務操作失敗：{error}',
      'backendHealthy': 'Bilirec 系統服務連線正常',
      'backendUnhealthy': 'Bilirec 系統服務回應異常，請稍後再試',
      'backendNoResponseHint': 'Bilirec 系統服務沒有回應，請確認已啟動',
      'backendCannotConnect': '目前無法連線到 Bilirec 系統服務，請確認已啟動',
      'startingShort': '啟動中',
      'stoppingShort': '停止中',
      'stop': '停止',
      'start': '啟動',
      'openFrontend': '打開錄製管理程式',
      'checkBackendConnection': '檢查系統服務連線',
      'settings': '打開服務啓動前設定',
      'generalSettingsTitle': '一般設定',
      'developerSettingsTitle': '開發者選項',
      'developerSectionDescription': '以下選項用於調整底層行為，不影響一般錄製功能。',
      'bootstrapLogTitle': '啟動日誌',
      'bootstrapLogDescription': '下載服務啟動日誌（bootstrap.log）以便回報問題。',
      'downloadBootstrapLog': '下載日誌',
      'downloadingLog': '下載中...',
      'selectLogDownloadPath': '選擇日誌儲存位置',
      'downloadBootstrapLogNotFound': '找不到 bootstrap.log，請先啟動過服務後再試。',
      'downloadBootstrapLogSuccess': '日誌已下載：{path}',
      'downloadBootstrapLogFailed': '下載日誌失敗：{error}',
      'environmentSettingsTitle': '環境參數設定',
      'environmentSettingsWarning': '警告：如不熟悉請勿觸碰。亂改可能造成手機發熱與耗電增加，並影響錄製效能；嚴重時後台可能被系統殺掉或限流。',
      'addEnvironmentSetting': '新增環境參數',
      'editEnvironmentSetting': '編輯環境參數',
      'environmentKeyLabel': '參數 Key',
      'environmentValueLabel': '參數 Value',
      'saveEnvironmentSetting': '儲存環境參數',
      'savedEnvironmentSettingsTitle': '已儲存的環境參數',
      'environmentSettingsEmpty': '目前尚未設定任何環境參數',
      'environmentValueEmpty': '(空值)',
      'removeEnvironmentSetting': '移除環境參數',
      'environmentKeyRequired': '請先輸入參數 Key',
      'storagePathTitle': '儲存路徑',
      'changePath': '變更路徑',
      'outputPathUnset': '目前尚未設定輸出路徑（使用預設）',
      'ssePushSwitchTitle': '本地通知模式',
      'ssePushDescription': '如在中國大陸網絡環境下無法接收開播/錄製通知推送，可嘗試啟用此模式。',
      'ssePushHint': '啓用後，點擊通知將無法直接跳轉到錄製管理程式',
      'antiSleepTitle': '激進防休眠模式',
      'antiSleepDescription': '如在關掉手機屏幕並閑置1~2小時後出現錄製斷斷續續或中斷的情況，可嘗試啓用此模式。',
      'antiSleepDisabledHint': '此功能可能會增加電池消耗，長時間錄製下建議連接電源使用。',
      'antiSleepEnabledHint': '通知欄標題顯示 ⚡ 即代表防休眠已生效。',
      'notificationTitleRunning': 'Bilirec 系統服務運行中',
      'notificationTextRunning': '打開錄製應用程式即可開始錄製',
      'notificationButtonStop': '停止服務',
      'recording': '錄製中',
      'sseDefaultStreamer': '主播',
      'sseTitleAutoRecord': '{streamer} 已開播，已開始自動錄製',
      'sseTitleAutoRecordFailed': '{streamer} 開播，但自動錄製失敗',
      'sseTitleLiveEnded': '{streamer} 已下播',
      'sseTitleRecordStopped': '{streamer} 錄製已停止',
      'sseTitleLive': '{streamer} 已開播',
      'sseUnknownEvent': '收到直播事件通知',
      'sseAtTime': '時間：{time}',
      'sseBodyDefault': '請打開錄製管理程式查看詳情',
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
      'backendNoResponse': 'Bilirec 系统服务沒有响应，请稍后再试',
      'cannotOpenFrontendBrowser': '无法打开录制管理程序',
      'ppkKilledTitle': 'Bilirec 系统服务已被终止',
      'ppkKilledBody': '检测到系统服务被中断，请重新启动，并确认已关闭省电限制。',
      'selectOutputPath': '选择录制输出路径',
      'batteryDialogTitle': '需要关闭省电限制',
      'batteryDialogContent': '请将 Bilirec 设为不受电池限制，否则系统服务可能被关闭。\n\n完成后请回到 App。',
      'goToSettings': '前往设置',
      'androidOnly': '目前仅支持 Android',
      'startingService': '正在启动 Bilirec 系统服务...',
      'notificationPermissionDenied': '通知权限未开启，无法启动系统服务',
      'foregroundStartWaitingCore': 'Bilirec 系统服务已启动，正在准备中...',
      'foregroundStopWaitingCore': 'Bilirec 系统服务已停止，正在等待退出...',
      'foregroundStartFailed': 'Bilirec 系统服务启动失败，请重试',
      'stopServiceFailed': 'Bilirec 系统服务停止失败',
      'serviceOperationFailed': '服务操作失败：{error}',
      'backendHealthy': 'Bilirec 系统服务连接正常',
      'backendUnhealthy': 'Bilirec 系统服务响应异常，请稍后再试',
      'backendNoResponseHint': 'Bilirec 系统服务没有响应，请确认已启动',
      'backendCannotConnect': '目前无法连接到 Bilirec 系统服务，请确认已启动',
      'startingShort': '启动中',
      'stoppingShort': '停止中',
      'stop': '停止',
      'start': '启动',
      'openFrontend': '打开录制管理程序',
      'checkBackendConnection': '检查系统服务连接',
      'settings': '打开服务启动前设置',
      'generalSettingsTitle': '一般设置',
      'developerSettingsTitle': '开发者选项',
      'developerSectionDescription': '以下选项用于调整底层行为，不影响一般录制功能。',
      'bootstrapLogTitle': '启动日志',
      'bootstrapLogDescription': '下载服务启动日志（bootstrap.log）以便反馈问题。',
      'downloadBootstrapLog': '下载日志',
      'downloadingLog': '下载中...',
      'selectLogDownloadPath': '选择日志保存位置',
      'downloadBootstrapLogNotFound': '找不到 bootstrap.log，请先启动过服务后再试。',
      'downloadBootstrapLogSuccess': '日志已下载：{path}',
      'downloadBootstrapLogFailed': '下载日志失败：{error}',
      'environmentSettingsTitle': '环境参数设置',
      'environmentSettingsWarning': '警告：如不熟悉请勿触碰。乱改可能造成手机发热与耗电增加，并影响录制性能；严重时后台可能被系统杀掉或限流。',
      'addEnvironmentSetting': '新增环境参数',
      'editEnvironmentSetting': '编辑环境参数',
      'environmentKeyLabel': '参数 Key',
      'environmentValueLabel': '参数 Value',
      'saveEnvironmentSetting': '保存环境参数',
      'savedEnvironmentSettingsTitle': '已保存的环境参数',
      'environmentSettingsEmpty': '目前尚未设置任何环境参数',
      'environmentValueEmpty': '(空值)',
      'removeEnvironmentSetting': '移除环境参数',
      'environmentKeyRequired': '请先输入参数 Key',
      'storagePathTitle': '保存路径',
      'changePath': '更改路径',
      'outputPathUnset': '目前尚未设置输出路径（使用默认）',
      'ssePushSwitchTitle': '本地通知模式',
      'ssePushDescription': '如在中国大陆网络环境下无法接收开播/录制通知推送，可尝试启用此模式。',
      'ssePushHint': '启用后，点击通知将无法直接跳转到录制管理程序',
      'antiSleepTitle': '激进防休眠模式',
      'antiSleepDescription': '如在关掉手机屏幕并闲置1~2小时后出现录制断断续续或中断的情况，可尝试启用此模式。',
      'antiSleepDisabledHint': '此功能可能会增加电池消耗，长时间录制下建议连接电源使用。',
      'antiSleepEnabledHint': '通知栏标题显示 ⚡ 即代表防休眠已生效。',
      'notificationTitleRunning': 'Bilirec 系统服务运行中',
      'notificationTextRunning': '打开录制应用程序即可开始录制',
      'notificationButtonStop': '停止服务',
      'recording': '录制中',
      'sseDefaultStreamer': '主播',
      'sseTitleAutoRecord': '{streamer} 已开播，已开始自动录制',
      'sseTitleAutoRecordFailed': '{streamer} 开播，但自动录制失败',
      'sseTitleLiveEnded': '{streamer} 已下播',
      'sseTitleRecordStopped': '{streamer} 录制已停止',
      'sseTitleLive': '{streamer} 已开播',
      'sseUnknownEvent': '收到直播事件通知',
      'sseAtTime': '时间：{time}',
      'sseBodyDefault': '请打开录制管理程序查看详情',
      'languageTraditional': '繁',
      'languageSimplified': '简',
      'languageMenuTooltip': '切换语言',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
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
