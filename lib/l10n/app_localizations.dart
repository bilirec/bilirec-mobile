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
      'externalStoragePermissionDenied': '儲存權限未開啟，無法寫入所選的外部路徑',
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
      'downloadBootstrapLogSuccess': '已合併 {count} 個日誌分片並匯出至：{path}',
      'downloadBootstrapLogFailed': '下載日誌失敗：{error}',
      'environmentSettingsTitle': '環境參數設定',
      'environmentSettingsWarning':
          '警告：如不熟悉請勿觸碰。亂改可能造成手機發熱與耗電增加，並影響錄製效能；嚴重時後台可能被系統殺掉或限流。',
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
      'storagePolicyTitle': '儲存策略',
      'storagePolicyDescription': '設定錄製檔案的輸出路徑與寫入方式。',
      'storagePathTitle': '輸出路徑',
      'changePath': '變更路徑',
      'outputPathUnset': '目前尚未設定輸出路徑（使用預設）',
      'microSdWearProtectionTitle': '啟用 microSD 卡磨損保護',
      'microSdWearProtectionDescription':
          '以輪流寫入方式降低 microSD 同時寫入峰值，延長卡片壽命。輸出到外置 SD 卡時請開啟；寫入節奏會隨「同時錄製上限」自動調節。',
      'ssePushSwitchTitle': '本地通知模式',
      'ssePushDescription': '如在中國大陸網絡環境下無法接收開播/錄製通知推送，可嘗試啟用此模式。',
      'ssePushHint': '啓用後，點擊通知將無法直接跳轉到錄製管理程式',
      'antiSleepTitle': '激進防休眠模式',
      'antiSleepDescription': '如在關掉手機屏幕並閑置1~2小時後出現錄製斷斷續續或中斷的情況，可嘗試啓用此模式。',
      'antiSleepDisabledHint': '此功能會增加電池消耗，長時間錄製下建議連接電源使用。',
      'antiSleepEnabledHint': '通知欄標題顯示 ⚡ 即代表防休眠已生效。',
      'recordingPolicyTitle': '錄製策略',
      'recordingPolicyDescription': '以下選項會影響錄製時長、重試行為與資源占用，可依裝置狀況調整。',
      'maxRecordingHoursTitle': '單次錄製時長上限',
      'maxRecordingHoursDescription': '限制每次錄製最長時長，避免長時間無人值守時占用過多儲存空間。',
      'minDiskSpaceTitle': '啟動前最低可用空間',
      'minDiskSpaceDescription': '僅在開始錄製前檢查。若可用空間低於門檻，該次錄製將不會啟動。',
      'maxRetryMinutesTitle': '下線後服務重試時長',
      'maxRetryMinutesDescription': '直播下線後，服務會持續重試到指定時長，再結束此次錄製。',
      'maxConcurrentRecordingsTitle': '同時錄製上限',
      'maxConcurrentRecordingsDescription': '限制同時進行的錄製數量，避免裝置長時間高負載。',
      'maxConcurrentRecordingsWarning': '提高此數值可能明顯增加耗電與發熱，並降低系統穩定性。',
      'conversionPolicyTitle': '轉換策略',
      'conversionPolicyDescription':
          '以下選項會影響影片轉檔行為。高效能操作會顯著增加耗電與發熱，請依手機硬體狀況調整。',
      'fileConversionTitle': '錄製後檔案轉換',
      'convertToMp4Title': '錄完自動轉為 MP4',
      'convertToMp4SecondaryDescription': '若手機執行記憶體 (RAM) 少於 8GB 建議關閉。',
      'convertToMp4Description': '開啟後可將錄製格式轉為 MP4 以提升播放相容性。\n注意：轉檔過程較耗電並會產生熱量。',
      'deleteSourceAfterConvertTitle': '轉檔後刪除原始檔',
      'deleteSourceAfterConvertDescription': '可節省儲存空間，僅保留轉換完成的 MP4 檔案。',
      'ffmpegSettingsTitle': '轉換工具進階設定',
      'ffmpegSettingsDescription': '調整錄製過程中的轉換行為，確保穩定性與效能平衡。',
      'ffmpegAllowDuringRecordingTitle': '錄製中允許轉換',
      'ffmpegAllowDuringRecordingDescription': '開啟後，App 將在錄製直播的同時同步在背景轉檔。',
      'ffmpegAllowDuringRecordingWarning':
          '同步轉換會增加磁碟讀寫負載，若遇到錄製掉幀或手機發熱，建議關閉此選項。',
      'ffmpegMaxActiveRecordingsTitle': '允許轉檔的「最高錄製路數」',
      'ffmpegMaxActiveRecordingsDescription':
          '當「正在錄製」的直播間數量超過此數值時，系統將自動暫停背景轉檔，優先確保錄製流暢。設定為 0 路表示不設限制（將面臨極高發熱與崩潰風險）。',
      'ffmpegMaxActiveOption': '{value} 路',
      'ffmpegMaxActiveUnlimitedOption': '不限',
      'hoursOption': '{value} 小時',
      'hoursUnlimitedOption': '不限',
      'minutesOption': '{value} 分鐘',
      'diskSpaceOption': '{value} GB',
      'concurrentRecordingOption': '{value} 路',
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
      'externalStoragePermissionDenied': '存储权限未开启，无法写入所选的外部路径',
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
      'downloadBootstrapLogSuccess': '已合并 {count} 个日志分片并导出至：{path}',
      'downloadBootstrapLogFailed': '下载日志失败：{error}',
      'environmentSettingsTitle': '环境参数设置',
      'environmentSettingsWarning':
          '警告：如不熟悉请勿触碰。乱改可能造成手机发热与耗电增加，并影响录制性能；严重时后台可能被系统杀掉或限流。',
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
      'storagePolicyTitle': '存储策略',
      'storagePolicyDescription': '设置录制文件的输出路径与写入方式。',
      'storagePathTitle': '输出路径',
      'changePath': '更改路径',
      'outputPathUnset': '目前尚未设置输出路径（使用默认）',
      'microSdWearProtectionTitle': '启用 microSD 卡磨损保护',
      'microSdWearProtectionDescription':
          '以轮流写入方式降低 microSD 同时写入峰值，延长卡片寿命。输出到外置 SD 卡时请开启；写入节奏会随「同时录制上限」自动调节。',
      'ssePushSwitchTitle': '本地通知模式',
      'ssePushDescription': '如在中国大陆网络环境下无法接收开播/录制通知推送，可尝试启用此模式。',
      'ssePushHint': '启用后，点击通知将无法直接跳转到录制管理程序',
      'antiSleepTitle': '激进防休眠模式',
      'antiSleepDescription': '如在关掉手机屏幕并闲置1~2小时后出现录制断断续续或中断的情况，可尝试启用此模式。',
      'antiSleepDisabledHint': '此功能会增加电池消耗，长时间录制下建议连接电源使用。',
      'antiSleepEnabledHint': '通知栏标题显示 ⚡ 即代表防休眠已生效。',
      'recordingPolicyTitle': '录制策略',
      'recordingPolicyDescription': '以下选项会影响录制时长、重试行为与资源占用，可按设备状态调整。',
      'maxRecordingHoursTitle': '单次录制时长上限',
      'maxRecordingHoursDescription': '限制每次录制最长时长，避免长时间无人值守时占用过多存储空间。',
      'minDiskSpaceTitle': '启动前最低可用空间',
      'minDiskSpaceDescription': '仅在开始录制前检查。若可用空间低于门槛，本次录制将不会启动。',
      'maxRetryMinutesTitle': '下线后服务重试时长',
      'maxRetryMinutesDescription': '直播下线后，服务会持续重试到指定时长，再结束此次录制。',
      'maxConcurrentRecordingsTitle': '同时录制上限',
      'maxConcurrentRecordingsDescription': '限制同时进行的录制数量，避免设备长时间高负载。',
      'maxConcurrentRecordingsWarning': '提高此数值可能明显增加耗电与发热，并降低系统稳定性。',
      'conversionPolicyTitle': '转换策略',
      'conversionPolicyDescription':
          '以下选项会影响视频转档行为。高性能操作会显著增加耗电与发热，请按手机硬件状态调整。',
      'fileConversionTitle': '录制后文件转换',
      'convertToMp4Title': '录完自动转为 MP4',
      'convertToMp4SecondaryDescription': '若手机运行内存 (RAM) 少于 8GB 建议关闭。',
      'convertToMp4Description': '开启后可将录制格式转为 MP4 以提升播放兼容性。\n注意：转档过程较耗电并会产生热量。',
      'deleteSourceAfterConvertTitle': '转档后删除原始文件',
      'deleteSourceAfterConvertDescription': '可节省存储空间，仅保留转换完成的 MP4 文件。',
      'ffmpegSettingsTitle': '转换工具进阶设置',
      'ffmpegSettingsDescription': '调整录制过程中的转换行为，确保稳定性与性能平衡。',
      'ffmpegAllowDuringRecordingTitle': '录制中允许转换',
      'ffmpegAllowDuringRecordingDescription': '开启后，App 将在录制直播的同时同步在后台转档。',
      'ffmpegAllowDuringRecordingWarning':
          '同步转换会增加磁碟读写负载，若遇到录制掉帧或手机发热，建议关闭此选项。',
      'ffmpegMaxActiveRecordingsTitle': '允许转档的「最高录制路数」',
      'ffmpegMaxActiveRecordingsDescription':
          '当「正在录制」的直播间数量超过此数值时，系统将自动暂停后台转档，优先确保录制流畅。设置为 0 路表示不设限制（将面临极高发热与崩溃风险）。',
      'ffmpegMaxActiveOption': '{value} 路',
      'ffmpegMaxActiveUnlimitedOption': '不限',
      'hoursOption': '{value} 小时',
      'hoursUnlimitedOption': '不限',
      'minutesOption': '{value} 分钟',
      'diskSpaceOption': '{value} GB',
      'concurrentRecordingOption': '{value} 路',
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
