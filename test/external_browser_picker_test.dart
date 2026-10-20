import 'dart:convert';
import 'dart:typed_data';

import 'package:bilirec/app/widgets/external_browser_picker_sheet.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/browser_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/l10n_test_helper.dart';

/// 1×1 PNG for [Image.memory] in widget tests.
final Uint8List _kTestBrowserIconPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.bilirec.bilirec/browser_packages');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listHttpsBrowsers') {
        return <dynamic>[
          {
            'packageName': 'com.example.browser',
            'label': 'Example Browser',
          },
        ];
      }
      if (call.method == 'loadHttpsBrowserIcons') {
        return <dynamic, dynamic>{
          'com.example.browser': _kTestBrowserIconPng,
        };
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('browser picker shows icons and returns selected package', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.traditionalLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  await showExternalBrowserPickerSheet(context);
                },
                child: const Text('Open picker'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('Example Browser'), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('Example Browser'));
    await tester.pumpAndSettle();

    expect(find.text('Example Browser'), findsNothing);
  });

  testWidgets('remember-choice picker still allows system default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.traditionalLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  final result = await showExternalBrowserPickerSheet(
                    context,
                    promptToRemember: true,
                  );
                  expect(result?.choice, externalBrowserChoiceSystem);
                },
                child: const Text('Open picker'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(labelsForKey('externalBrowserSystemDefault').first),
    );
    await tester.tap(
      find.text(labelsForKey('externalBrowserPickerConfirm').first),
    );
    await tester.pumpAndSettle();
  });
}
