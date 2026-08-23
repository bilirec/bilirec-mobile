import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/unexpected_stop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/l10n_test_helper.dart';

void main() {
  UnexpectedStopCause? classify({
    bool serviceRunning = false,
    bool intendedRunning = true,
    bool stoppedByUser = false,
    bool promptMuted = false,
    int? lastStartId = 1,
    int? consumedStartId,
    String? lastBootId,
    String? currentBootId,
  }) {
    return classifyUnexpectedStop(
      serviceRunning: serviceRunning,
      intendedRunning: intendedRunning,
      stoppedByUser: stoppedByUser,
      promptMuted: promptMuted,
      lastStartId: lastStartId,
      consumedStartId: consumedStartId,
      lastBootId: lastBootId,
      currentBootId: currentBootId,
    );
  }

  test('從未啟動、使用者停止或已靜音時不提示', () {
    expect(classify(intendedRunning: false), isNull);
    expect(classify(lastStartId: null), isNull);
    expect(classify(stoppedByUser: true), isNull);
    expect(classify(promptMuted: true), isNull);
    expect(classify(serviceRunning: true), isNull);
    expect(classify(consumedStartId: 1), isNull);
  });

  test('boot_id 改變視為重啟，否則視為後台被殺', () {
    expect(
      classify(
        lastBootId: 'boot-a',
        currentBootId: 'boot-b',
      ),
      UnexpectedStopCause.reboot,
    );
    expect(
      classify(
        lastBootId: 'boot-a',
        currentBootId: 'boot-a',
      ),
      UnexpectedStopCause.backgroundKill,
    );
    expect(
      classify(lastBootId: null, currentBootId: 'boot-a'),
      UnexpectedStopCause.backgroundKill,
    );
  });

  test('重啟且未開開機自啟時引導開啟自啟，其餘導向設定教學', () {
    expect(
      resolveUnexpectedStopPrompt(
        cause: UnexpectedStopCause.reboot,
        autoRunOnBootEnabled: false,
      )?.kind,
      UnexpectedStopPromptKind.enableAutoRunOnBoot,
    );
    expect(
      resolveUnexpectedStopPrompt(
        cause: UnexpectedStopCause.reboot,
        autoRunOnBootEnabled: true,
      )?.kind,
      UnexpectedStopPromptKind.openOemDocs,
    );
    expect(
      resolveUnexpectedStopPrompt(
        cause: UnexpectedStopCause.backgroundKill,
        autoRunOnBootEnabled: false,
      )?.kind,
      UnexpectedStopPromptKind.openOemDocs,
    );
    expect(
      resolveUnexpectedStopPrompt(
        cause: null,
        autoRunOnBootEnabled: false,
      ),
      isNull,
    );
  });

  test('設定教學連結依語系切換 zh-cn / zh-tw', () {
    expect(
      androidMainlandDocsUrl(AppLocaleConfig.simplifiedLocale),
      'https://www.bilirec.org/zh-cn/guides/android-mainland/',
    );
    expect(
      androidMainlandDocsUrl(AppLocaleConfig.traditionalLocale),
      'https://www.bilirec.org/zh-tw/guides/android-mainland/',
    );
  });

  test('已移除被殺當下通知文案', () {
    expect(labelsForKey('ppkKilledTitle'), ['ppkKilledTitle']);
    expect(labelsForKey('ppkKilledBody'), ['ppkKilledBody']);
  });
}
