import 'package:bilirec/app/widgets/unexpected_stop_dialog.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/unexpected_stop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/l10n_test_helper.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required UnexpectedStopPrompt prompt,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.traditionalLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: UnexpectedStopDialog(prompt: prompt),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('重啟且未開自啟時顯示開機自動恢復文案', (tester) async {
    await pumpDialog(
      tester,
      prompt: const UnexpectedStopPrompt(
        cause: UnexpectedStopCause.reboot,
        kind: UnexpectedStopPromptKind.enableAutoRunOnBoot,
      ),
    );

    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopRebootTitle',
        AppLocaleConfig.traditionalCode,
      )),
      findsOneWidget,
    );
    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopRebootEnableBoot',
        AppLocaleConfig.traditionalCode,
      )),
      findsOneWidget,
    );
    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopViewSetupGuide',
        AppLocaleConfig.traditionalCode,
      )),
      findsNothing,
    );
    expect(find.textContaining('設定教學'), findsNothing);
    expect(find.textContaining('背景被殺'), findsNothing);
  });

  testWidgets('重啟且已開自啟時顯示國產系統說明與設定教學', (tester) async {
    await pumpDialog(
      tester,
      prompt: const UnexpectedStopPrompt(
        cause: UnexpectedStopCause.reboot,
        kind: UnexpectedStopPromptKind.rebootNotice,
      ),
    );

    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopBlockedBootTitle',
        AppLocaleConfig.traditionalCode,
      )),
      findsOneWidget,
    );
    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopBlockedBootBody',
        AppLocaleConfig.traditionalCode,
      )),
      findsOneWidget,
    );
    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopViewSetupGuide',
        AppLocaleConfig.traditionalCode,
      )),
      findsOneWidget,
    );
    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopRebootEnableBoot',
        AppLocaleConfig.traditionalCode,
      )),
      findsNothing,
    );
    expect(
      find.textContaining('背景被殺'),
      findsNothing,
    );
  });

  testWidgets('後台被殺時顯示設定教學主按鈕', (tester) async {
    await pumpDialog(
      tester,
      prompt: const UnexpectedStopPrompt(
        cause: UnexpectedStopCause.backgroundKill,
        kind: UnexpectedStopPromptKind.openOemDocs,
      ),
    );

    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopKillTitle',
        AppLocaleConfig.traditionalCode,
      )),
      findsOneWidget,
    );
    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopViewSetupGuide',
        AppLocaleConfig.traditionalCode,
      )),
      findsOneWidget,
    );
    expect(
      find.text(labelForKeyAndCode(
        'unexpectedStopRebootEnableBoot',
        AppLocaleConfig.traditionalCode,
      )),
      findsNothing,
    );
  });
}
