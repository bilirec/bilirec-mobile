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
      'cannotOpenFrontendBrowser': '無法開啟錄製管理程式',
      'selectOutputPath': '選擇錄製輸出路徑',
      'outputPathPermissionDialogTitle': '需要授權存取所有檔案權限',
      'outputPathPermissionDialogContent': '若要選擇輸出路徑，請先授權 Bilirec 存取所有檔案權限。',
      'outputPathPermissionDialogConfirm': '同意授權',
      'batteryDialogTitle': '需要關閉省電限制',
      'batteryDialogContent': '請將 Bilirec 設為不受電池限制，否則系統服務可能被關閉。\n\n完成後請回到 App。',
      'goToSettings': '前往設定',
      'unexpectedStopRebootTitle': '服務因手機重啟而停止',
      'unexpectedStopRebootBody':
          '偵測到手機曾重新開機，錄製服務因此停止。\n\n建議開啟「開機自動恢復」（開啟後需再成功啟動一次服務才會生效）。',
      'unexpectedStopRebootEnableBoot': '開啟開機自動恢復',
      'unexpectedStopViewSetupGuide': '查看設定教學',
      'unexpectedStopKillTitle': '服務被系統停止',
      'unexpectedStopKillBody':
          '偵測到 Bilirec 服務在背景被殺，錄製服務因此停止。\n\n部分國產手機系統對背景運作有較嚴格的限制；如果你使用國產手機系統，可參考設定教學，允許背景運作與自啟動，降低再次被停止的機會。',
      'unexpectedStopBlockedBootTitle': '開機後服務沒有自動恢復',
      'unexpectedStopBlockedBootBody':
          '偵測到手機重新開機後，系統阻止了服務自動恢復。\n\n部分國產手機系統會攔截自啟動；如果你使用國產手機系統，可參考設定教學，允許自啟動與背景運作。',
      'unexpectedStopDismiss': '關閉',
      'unexpectedStopDontRemind': '不再提醒',
      'unexpectedStopBootEnabledHint': '已開啟開機自動恢復。請再成功啟動一次服務後才會生效。',
      'updateDialogTitle': '發現新版本 {version}',
      'updateDialogContent': '已偵測到新版本（{version}），建議立即更新。',
      'updateDialogUpdateNow': '立即更新',
      'updateDialogLater': '稍後',
      'updateDialogSkipVersion': '此版本不再提醒',
      'updateDownloadStarted': '開始下載更新...',
      'updateProgressDialogTitle': '下載更新中',
      'updateProgressDialogHint': '請保持 App 在前景，完成後會自動前往安裝。',
      'updateProgressDialogPreparing': '正在準備下載...',
      'updateProgressDialogPercent': '下載進度：{progress}%',
      'updateInstallPromptHint': '下載完成，請在安裝頁完成更新。',
      'updateOpenReleaseFallbackHint': '自動安裝失敗，已改為開啟下載頁面。',
      'updateOpenReleaseFailed': '更新失敗，且無法開啟下載頁面',
      'updateSignatureMismatchTitle': '簽名校驗失敗',
      'updateSignatureMismatchContent':
          '已下載的更新檔與目前 App 的簽署憑證不一致，已拒絕安裝，以免安裝到不可信的檔案。\n\n你可以改從 GitHub 發行頁手動下載官方 APK。',
      'updateSignatureMismatchOpenGithub': '前往 GitHub 下載',
      'updateSignatureMismatchDismiss': '關閉',
      'androidOnly': '目前只支援 Android',
      'startingService': '正在啟動 Bilirec 系統服務...',
      'notificationPermissionDenied': '通知權限未開啟，無法啟動系統服務',
      'externalStoragePermissionDenied': '儲存權限未開啟，無法寫入所選的外部路徑',
      'startServiceExternalPathPermissionDialogTitle': '需要授權存取所有檔案權限',
      'startServiceExternalPathPermissionDialogContent':
          '目前輸出路徑位於外部儲存空間，啟動服務前請先授權 Bilirec 存取所有檔案權限。',
      'startServiceExternalPathPermissionDialogConfirm': '同意授權',
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
      'openFrontend': '開啟錄製管理程式',
      'checkBackendConnection': '檢查系統服務連線',
      'settings': '開啟服務啟動前設定',
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
      'subscriptionListTransferTitle': '訂閱清單匯入／匯出',
      'subscriptionListTransferDescription':
          '可匯入或匯出 bilirec 的 subscribes.db，方便搬移與備份訂閱清單。',
      'exportSubscriptionList': '匯出',
      'importSubscriptionList': '匯入',
      'resetSubscriptionList': '重設',
      'selectSubscriptionListExportPath': '選擇訂閱清單匯出位置',
      'selectSubscriptionListImportFile': '選擇要匯入的 subscribes.db',
      'subscriptionListNotFound': '找不到 subscribes.db，請先啟動服務後再試。',
      'exportSubscriptionListSuccess': '已匯出訂閱清單至：{path}',
      'exportSubscriptionListFailed': '匯出訂閱清單失敗：{error}',
      'importSubscriptionRiskTitle': '匯入訂閱清單風險提示',
      'importSubscriptionRiskDescription':
          '匯入非 bilirec 的 subscribes.db 或損毀的資料庫檔案，可能導致訂閱資料損毀，甚至造成服務無法啟動。請確認欲匯入的檔案為 bilirec 的 subscribes.db。',
      'importSubscriptionRiskConfirm': '我已知曉風險並繼續',
      'resetSubscriptionListWarningTitle': '重設訂閱清單警告',
      'resetSubscriptionListWarningDescription':
          '重設主要用於當匯入損毀的 subscribes.db 導致 App 無法啟動時的救援操作。此操作會刪除 subscribes.db 並清空所有訂閱，且無法復原。',
      'resetSubscriptionListWarningConfirm': '我已知曉會清空並繼續',
      'resetSubscriptionListSuccess': '已重設訂閱清單：{path}',
      'resetSubscriptionListFailed': '重設訂閱清單失敗：{error}',
      'importSubscriptionListInvalidFile': '選取的檔案無法讀取，請重新選擇。',
      'importSubscriptionListSamePath': '目前選到的就是 app 內建資料庫，無需再次匯入。',
      'importSubscriptionListSuccess': '已匯入訂閱清單到：{path}',
      'importSubscriptionListFailed': '匯入訂閱清單失敗：{error}',
      'environmentSettingsTitle': '環境變數設定',
      'environmentSettingsWarning':
          '警告：如不熟悉請勿觸碰。亂改可能造成手機發熱與耗電增加，並影響錄製效能；嚴重時背景可能被系統殺掉或限流。',
      'addEnvironmentSetting': '新增環境變數',
      'editEnvironmentSetting': '編輯環境變數',
      'environmentKeyLabel': '變數 Key',
      'environmentValueLabel': '變數 Value',
      'saveEnvironmentSetting': '儲存環境變數',
      'savedEnvironmentSettingsTitle': '已儲存的環境變數',
      'environmentSettingsEmpty': '目前尚未設定任何環境變數',
      'environmentValueEmpty': '(空值)',
      'removeEnvironmentSetting': '移除環境變數',
      'environmentKeyRequired': '請先輸入變數 Key',
      'storagePolicyTitle': '儲存策略',
      'storagePolicyDescription': '設定錄製檔案的輸出路徑與寫入方式。',
      'storagePathTitle': '輸出路徑',
      'changePath': '變更路徑',
      'restoreDefaultPath': '恢復預設',
      'outputPathUnset': '目前尚未設定輸出路徑（使用預設）',
      'microSdWearProtectionTitle': '啟用 microSD 卡磨損保護',
      'microSdWearProtectionDescription':
          '以輪流寫入方式降低 microSD 同時寫入峰值，延長卡片壽命。輸出到外接 SD 卡時請開啟；寫入節奏會隨「同時錄製上限」自動調節。',
      'ssePushSwitchTitle': '本地通知模式',
      'ssePushDescription': '如在中國大陸網路環境下無法接收開播/錄製通知推送，可嘗試啟用此模式。',
      'ssePushHint': '啟用後，點選通知將無法直接前往錄製管理程式',
      'antiSleepTitle': '激進防休眠模式',
      'antiSleepDescription': '如在關掉手機螢幕並閒置1~2小時後出現錄製斷斷續續或中斷的情況，可嘗試啟用此模式。',
      'antiSleepDisabledHint': '此功能會增加電池消耗，長時間錄製下建議連接電源使用。',
      'antiSleepEnabledHint': '通知欄標題顯示 ⚡ 即代表防休眠已生效。',
      'autoRunOnBootTitle': '開機自動恢復服務',
      'autoRunOnBootDescription': '手機重啟後，若當時服務仍在運行，會自動再拉起。已手動停止則不會自啟動。',
      'autoRunOnBootHint': '開啟後需再成功啟動一次服務才會生效。部分國產系統還要在系統設定允許自啟動。',
      'recordingPolicyTitle': '錄製策略',
      'recordingPolicyDescription': '以下選項會影響錄製時長、重試行為與資源占用，可依裝置狀況調整。',
      'maxRecordingHoursTitle': '單次錄製時長上限',
      'maxRecordingHoursDescription': '限制每次錄製最長時長，避免長時間無人值守時占用過多儲存空間。',
      'minDiskSpaceTitle': '啟動前最低可用空間',
      'minDiskSpaceDescription': '僅在開始錄製前檢查。若可用空間低於門檻，該次錄製將不會啟動。',
      'maxRetryMinutesTitle': '下線後服務重試時長',
      'maxRetryMinutesDescription': '直播下線後，服務會持續重試到指定時長，再結束此次錄製。',
      'recordingRecoveryDurationTitle': '重試成功後的時長計算',
      'recordingRecoveryDurationDescription':
          '斷流後若重試成功並恢復錄製，可選擇從頭起算錄製時長，或沿用開始錄製時的總時長。',
      'recordingRecoveryDurationPreserve': '保留',
      'recordingRecoveryDurationReset': '重設',
      'recordingRecoveryDurationPreserveHint': '錄製時長仍從開始錄製起算，不延長。',
      'recordingRecoveryDurationResetHint': '錄製時長從重試成功時重新計算。',
      'maxConcurrentRecordingsTitle': '同時錄製上限',
      'maxConcurrentRecordingsDescription': '限制同時進行的錄製數量，避免裝置長時間高負載。',
      'maxConcurrentRecordingsWarning': '提高此數值可能明顯增加耗電與發熱，並降低系統穩定性。',
      'danmakuPolicyTitle': '彈幕策略',
      'danmakuPolicyDescription':
          '這裡只決定彈幕檔案格式與高峰時的處理方式。是否同時錄製彈幕，請在錄製管理程式中為每次錄製或房間開啟。',
      'danmakuOutputFormatTitle': '彈幕檔案格式',
      'danmakuOutputFormatDescription':
          '選擇彈幕與互動記錄的儲存格式。Web 回放彈幕滾動與禮物特效需要 jsonl。',
      'danmakuOutputFormatJsonl': 'jsonl',
      'danmakuOutputFormatXml': 'xml',
      'danmakuOutputFormatJsonlHint': '適合在錄製管理程式回放彈幕與互動特效。',
      'danmakuOutputFormatXmlHint': '方便交給其他工具；Web 回放不會顯示彈幕滾動與禮物特效。',
      'danmakuOverflowPolicyTitle': '訊息高峰處理',
      'danmakuOverflowPolicyDescription': '彈幕來得比寫入快、等待佇列已滿時，決定如何處理新訊息。',
      'danmakuOverflowPolicyDrop': '丟棄',
      'danmakuOverflowPolicyBlock': '等待',
      'danmakuOverflowPolicyDropHint': '佇列滿時會捨棄新訊息，以換取較低延遲，讓彈幕與畫面保持同步。',
      'danmakuOverflowPolicyBlockHint': '完整保留彈幕訊息；若寫入發生延遲，可能會導致彈幕與畫面時間不同步。',
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
      'notificationTextRunning': '開啟錄製管理程式即可開始錄製',
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
      'sseBodyDefault': '請開啟錄製管理程式查看詳情',
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
      'backendNoResponse': 'Bilirec 系统服务没有响应，请稍后再试',
      'cannotOpenFrontendBrowser': '无法打开录制管理程序',
      'selectOutputPath': '选择录制输出路径',
      'outputPathPermissionDialogTitle': '需要授权访问所有文件权限',
      'outputPathPermissionDialogContent': '若要选择输出路径，请先授权 Bilirec 访问所有文件权限。',
      'outputPathPermissionDialogConfirm': '同意授权',
      'batteryDialogTitle': '需要关闭省电限制',
      'batteryDialogContent': '请将 Bilirec 设为不受电池限制，否则系统服务可能被关闭。\n\n完成后请回到 App。',
      'goToSettings': '前往设置',
      'unexpectedStopRebootTitle': '服务因手机重启而停止',
      'unexpectedStopRebootBody':
          '检测到手机曾重新开机，录制服务因此停止。\n\n建议开启「开机自动恢复」（开启后需再成功启动一次服务才会生效）。',
      'unexpectedStopRebootEnableBoot': '开启开机自动恢复',
      'unexpectedStopViewSetupGuide': '查看设置教程',
      'unexpectedStopKillTitle': '服务被系统停止',
      'unexpectedStopKillBody':
          '检测到 Bilirec 服务在后台被杀，录制服务因此停止。\n\n部分国产手机系统对后台运行有较严格的限制；如果你使用国产手机系统，可参考设置教程，允许后台运行与自启动，降低再次被停止的几率。',
      'unexpectedStopBlockedBootTitle': '开机后服务没有自动恢复',
      'unexpectedStopBlockedBootBody':
          '检测到手机重新开机后，系统阻止了服务自动恢复。\n\n部分国产手机系统会拦截自启动；如果你使用国产手机系统，可参考设置教程，允许自启动与后台运行。',
      'unexpectedStopDismiss': '关闭',
      'unexpectedStopDontRemind': '不再提醒',
      'unexpectedStopBootEnabledHint': '已开启开机自动恢复。请再成功启动一次服务后才会生效。',
      'updateDialogTitle': '发现新版本 {version}',
      'updateDialogContent': '已检测到新版本（{version}），建议立即更新。',
      'updateDialogUpdateNow': '立即更新',
      'updateDialogLater': '稍后',
      'updateDialogSkipVersion': '此版本不再提醒',
      'updateDownloadStarted': '开始下载更新...',
      'updateProgressDialogTitle': '下载更新中',
      'updateProgressDialogHint': '请保持 App 在前台，完成后会自动跳转安装。',
      'updateProgressDialogPreparing': '正在准备下载...',
      'updateProgressDialogPercent': '下载进度：{progress}%',
      'updateInstallPromptHint': '下载完成，请在安装页完成更新。',
      'updateOpenReleaseFallbackHint': '自动安装失败，已改为打开下载页面。',
      'updateOpenReleaseFailed': '更新失败，且无法打开下载页面',
      'updateSignatureMismatchTitle': '签名校验失败',
      'updateSignatureMismatchContent':
          '已下载的更新文件与当前 App 的签署证书不一致，已拒绝安装，以免安装到不可信的文件。\n\n你可以改从 GitHub 发行页手动下载官方 APK。',
      'updateSignatureMismatchOpenGithub': '前往 GitHub 下载',
      'updateSignatureMismatchDismiss': '关闭',
      'androidOnly': '目前仅支持 Android',
      'startingService': '正在启动 Bilirec 系统服务...',
      'notificationPermissionDenied': '通知权限未开启，无法启动系统服务',
      'externalStoragePermissionDenied': '存储权限未开启，无法写入所选的外部路径',
      'startServiceExternalPathPermissionDialogTitle': '需要授权访问所有文件权限',
      'startServiceExternalPathPermissionDialogContent':
          '当前输出路径位于外部存储空间，启动服务前请先授权 Bilirec 访问所有文件权限。',
      'startServiceExternalPathPermissionDialogConfirm': '同意授权',
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
      'subscriptionListTransferTitle': '订阅列表导入／导出',
      'subscriptionListTransferDescription':
          '可导入或导出 bilirec 的 subscribes.db，方便迁移与备份订阅列表。',
      'exportSubscriptionList': '导出',
      'importSubscriptionList': '导入',
      'resetSubscriptionList': '重置',
      'selectSubscriptionListExportPath': '选择订阅列表导出位置',
      'selectSubscriptionListImportFile': '选择要导入的 subscribes.db',
      'subscriptionListNotFound': '找不到 subscribes.db，请先启动服务后再试。',
      'exportSubscriptionListSuccess': '已导出订阅列表至：{path}',
      'exportSubscriptionListFailed': '导出订阅列表失败：{error}',
      'importSubscriptionRiskTitle': '导入订阅列表风险提示',
      'importSubscriptionRiskDescription':
          '导入非 bilirec 的 subscribes.db 或损坏的数据库文件，可能导致订阅数据损坏，甚至使服务无法启动。请确认要导入的文件为 bilirec 的 subscribes.db。',
      'importSubscriptionRiskConfirm': '我已知晓风险并继续',
      'resetSubscriptionListWarningTitle': '重置订阅列表警告',
      'resetSubscriptionListWarningDescription':
          '重置主要用于在导入损坏的 subscribes.db 导致 App 无法启动时作为救援操作。此操作会删除 subscribes.db 并清空所有订阅，且无法恢复。',
      'resetSubscriptionListWarningConfirm': '我已知晓会清空并继续',
      'resetSubscriptionListSuccess': '已重置订阅列表：{path}',
      'resetSubscriptionListFailed': '重置订阅列表失败：{error}',
      'importSubscriptionListInvalidFile': '选择的文件无法读取，请重新选择。',
      'importSubscriptionListSamePath': '当前选到的就是 app 内置数据库，无需再次导入。',
      'importSubscriptionListSuccess': '已导入订阅列表到：{path}',
      'importSubscriptionListFailed': '导入订阅列表失败：{error}',
      'environmentSettingsTitle': '环境变量设置',
      'environmentSettingsWarning':
          '警告：如不熟悉请勿触碰。乱改可能造成手机发热与耗电增加，并影响录制性能；严重时后台可能被系统杀掉或限流。',
      'addEnvironmentSetting': '新增环境变量',
      'editEnvironmentSetting': '编辑环境变量',
      'environmentKeyLabel': '变量 Key',
      'environmentValueLabel': '变量 Value',
      'saveEnvironmentSetting': '保存环境变量',
      'savedEnvironmentSettingsTitle': '已保存的环境变量',
      'environmentSettingsEmpty': '目前尚未设置任何环境变量',
      'environmentValueEmpty': '(空值)',
      'removeEnvironmentSetting': '移除环境变量',
      'environmentKeyRequired': '请先输入变量 Key',
      'storagePolicyTitle': '存储策略',
      'storagePolicyDescription': '设置录制文件的输出路径与写入方式。',
      'storagePathTitle': '输出路径',
      'changePath': '更改路径',
      'restoreDefaultPath': '恢复默认',
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
      'autoRunOnBootTitle': '开机自动恢复服务',
      'autoRunOnBootDescription': '手机重启后，若当时服务仍在运行，会自动再拉起。已手动停止则不会自启动。',
      'autoRunOnBootHint': '开启后需再成功启动一次服务才会生效。部分国产系统还要在系统设置允许自启动。',
      'recordingPolicyTitle': '录制策略',
      'recordingPolicyDescription': '以下选项会影响录制时长、重试行为与资源占用，可按设备状态调整。',
      'maxRecordingHoursTitle': '单次录制时长上限',
      'maxRecordingHoursDescription': '限制每次录制最长时长，避免长时间无人值守时占用过多存储空间。',
      'minDiskSpaceTitle': '启动前最低可用空间',
      'minDiskSpaceDescription': '仅在开始录制前检查。若可用空间低于门槛，本次录制将不会启动。',
      'maxRetryMinutesTitle': '下线后服务重试时长',
      'maxRetryMinutesDescription': '直播下线后，服务会持续重试到指定时长，再结束此次录制。',
      'recordingRecoveryDurationTitle': '重试成功后的时长计算',
      'recordingRecoveryDurationDescription':
          '断流后若重试成功并恢复录制，可选择从头起算录制时长，或沿用开始录制时的总时长。',
      'recordingRecoveryDurationPreserve': '保留',
      'recordingRecoveryDurationReset': '重置',
      'recordingRecoveryDurationPreserveHint': '录制时长仍从开始录制起算，不延长。',
      'recordingRecoveryDurationResetHint': '录制时长从重试成功时重新计算。',
      'maxConcurrentRecordingsTitle': '同时录制上限',
      'maxConcurrentRecordingsDescription': '限制同时进行的录制数量，避免设备长时间高负载。',
      'maxConcurrentRecordingsWarning': '提高此数值可能明显增加耗电与发热，并降低系统稳定性。',
      'danmakuPolicyTitle': '弹幕策略',
      'danmakuPolicyDescription':
          '这里只决定弹幕文件格式与高峰时的处理方式。是否同时录制弹幕，请在录制管理程序中为每次录制或房间开启。',
      'danmakuOutputFormatTitle': '弹幕文件格式',
      'danmakuOutputFormatDescription':
          '选择弹幕与互动记录的存储格式。Web 回放弹幕滚动与礼物特效需要 jsonl。',
      'danmakuOutputFormatJsonl': 'jsonl',
      'danmakuOutputFormatXml': 'xml',
      'danmakuOutputFormatJsonlHint': '适合在录制管理程序回放弹幕与互动特效。',
      'danmakuOutputFormatXmlHint': '方便交给其他工具；Web 回放不会显示弹幕滚动与礼物特效。',
      'danmakuOverflowPolicyTitle': '消息高峰处理',
      'danmakuOverflowPolicyDescription': '弹幕来得比写入快、等待队列已满时，决定如何处理新消息。',
      'danmakuOverflowPolicyDrop': '丢弃',
      'danmakuOverflowPolicyBlock': '等待',
      'danmakuOverflowPolicyDropHint': '队列满时会丢弃新消息，以换取较低延迟，让弹幕与画面保持同步。',
      'danmakuOverflowPolicyBlockHint': '完整保留弹幕消息；若写入发生延迟，可能会导致弹幕与画面时间不同步。',
      'conversionPolicyTitle': '转换策略',
      'conversionPolicyDescription':
          '以下选项会影响视频转换行为。高性能操作会显著增加耗电与发热，请按手机硬件状态调整。',
      'fileConversionTitle': '录制后文件转换',
      'convertToMp4Title': '录完自动转为 MP4',
      'convertToMp4SecondaryDescription': '若手机运行内存 (RAM) 少于 8GB 建议关闭。',
      'convertToMp4Description': '开启后可将录制格式转为 MP4 以提升播放兼容性。\n注意：转换过程较耗电并会产生热量。',
      'deleteSourceAfterConvertTitle': '转换后删除原始文件',
      'deleteSourceAfterConvertDescription': '可节省存储空间，仅保留转换完成的 MP4 文件。',
      'ffmpegSettingsTitle': '转换工具进阶设置',
      'ffmpegSettingsDescription': '调整录制过程中的转换行为，确保稳定性与性能平衡。',
      'ffmpegAllowDuringRecordingTitle': '录制中允许转换',
      'ffmpegAllowDuringRecordingDescription': '开启后，App 将在录制直播的同时同步在后台转换。',
      'ffmpegAllowDuringRecordingWarning':
          '同步转换会增加磁盘读写负载，若遇到录制掉帧或手机发热，建议关闭此选项。',
      'ffmpegMaxActiveRecordingsTitle': '允许转换的「最高录制路数」',
      'ffmpegMaxActiveRecordingsDescription':
          '当「正在录制」的直播间数量超过此数值时，系统将自动暂停后台转换，优先确保录制流畅。设置为 0 路表示不设限制（将面临极高发热与崩溃风险）。',
      'ffmpegMaxActiveOption': '{value} 路',
      'ffmpegMaxActiveUnlimitedOption': '不限',
      'hoursOption': '{value} 小时',
      'hoursUnlimitedOption': '不限',
      'minutesOption': '{value} 分钟',
      'diskSpaceOption': '{value} GB',
      'concurrentRecordingOption': '{value} 路',
      'notificationTitleRunning': 'Bilirec 系统服务运行中',
      'notificationTextRunning': '打开录制管理程序即可开始录制',
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
