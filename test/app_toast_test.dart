import 'package:bilirec/shared/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpToastHost(
    WidgetTester tester, {
    required void Function(BuildContext context) onPressed,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () => onPressed(context),
                  child: const Text('show toast'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  tearDown(() {
    AppToastController.dismiss();
  });

  testWidgets('AppToast 使用較淺色的背景與深色文字', (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8EDBFF)),
      useMaterial3: true,
    );
    final expectedBackground = theme.colorScheme.surface.withValues(alpha: 0.97);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: AppToast(
            message: '淺色 toast',
            location: AppToastLocation.bottom,
            edgeDistance: 40,
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppToast),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, expectedBackground);
    expect(find.text('淺色 toast'), findsOneWidget);
  });

  testWidgets('AppToast 可設定 top 位置與 edgeDistance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppToast(
            message: 'top toast',
            location: AppToastLocation.top,
            edgeDistance: 12,
          ),
        ),
      ),
    );

    final align = tester.widget<Align>(
      find.descendant(
        of: find.byType(AppToast),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, Alignment.topCenter);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppToast),
        matching: find.byType(Container),
      ),
    );
    expect(container.margin, const EdgeInsets.fromLTRB(24, 12, 24, 0));
  });

  testWidgets('showAppToast 可使用 fade animation', (tester) async {
    await pumpToastHost(
      tester,
      onPressed: (context) => showAppToast(
        context,
        'fade toast',
        duration: const Duration(milliseconds: 250),
        animation: AppToastAnimation.fade,
      ),
    );

    await tester.tap(find.text('show toast'));
    await tester.pump();

    expect(find.byType(AppToast), findsOneWidget);
    expect(find.text('fade toast'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(AppToast),
        matching: find.byType(FadeTransition),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(AppToast),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );

    AppToastController.dismiss();
    await tester.pumpAndSettle();
    expect(find.byType(AppToast), findsNothing);
    expect(find.text('fade toast'), findsNothing);
  });

  testWidgets('showAppToast 可使用 slide animation 並顯示 emoji 文字', (tester) async {
    await pumpToastHost(
      tester,
      onPressed: (context) => showAppToast(
        context,
        '✅ 系統服務連線正常',
        duration: const Duration(milliseconds: 250),
        animation: AppToastAnimation.slide,
      ),
    );

    await tester.tap(find.text('show toast'));
    await tester.pump();

    expect(find.byType(AppToast), findsOneWidget);
    expect(find.text('✅ 系統服務連線正常'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(AppToast),
        matching: find.byType(SlideTransition),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(AppToast),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    final slide = tester.widget<SlideTransition>(
      find.ancestor(
        of: find.byType(AppToast),
        matching: find.byType(SlideTransition),
      ),
    );
    final beginOffset = slide.position.value;
    expect(beginOffset.dy, greaterThan(0));

    AppToastController.dismiss();
    await tester.pumpAndSettle();
    expect(find.byType(AppToast), findsNothing);
  });

  testWidgets('showAppToast 在 top + slide 時會由上往下滑入', (tester) async {
    await pumpToastHost(
      tester,
      onPressed: (context) => showAppToast(
        context,
        'top slide toast',
        duration: const Duration(milliseconds: 250),
        animation: AppToastAnimation.slide,
        location: AppToastLocation.top,
        edgeDistance: 8,
      ),
    );

    await tester.tap(find.text('show toast'));
    await tester.pump();

    expect(find.text('top slide toast'), findsOneWidget);
    final align = tester.widget<Align>(
      find.descendant(
        of: find.byType(AppToast),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, Alignment.topCenter);

    final slide = tester.widget<SlideTransition>(
      find.ancestor(
        of: find.byType(AppToast),
        matching: find.byType(SlideTransition),
      ),
    );
    final beginOffset = slide.position.value;
    expect(beginOffset.dy, lessThan(0));
  });
}




