// U9: the opening on a cold start — a page, the camera frame closing with a
// flash, then the し stroke — in 1.2 s at most, skipped by a tap, left out
// when the system asks for reduced motion, and never again on resume. Its
// background is the launch screen's (the page background token).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';

import '../support/design.dart';
import '../support/harness.dart';
import '../support/study_modes.dart';

const _opening = ValueKey('opening');

Future<void> _start(WidgetTester tester, {bool firstLaunch = true}) async {
  usePhoneSize(tester);
  final blocks = TestBlocks();
  await seedModeWords(blocks);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...blocks.overrides,
        ...designBlocks(),
        onboardingStoreProvider.overrideWithValue(
          InMemoryOnboardingStore(seen: true),
        ),
      ],
      child: ShioriApp(firstLaunch: firstLaunch),
    ),
  );
}

void main() {
  testWidgets('a cold start shows the opening over a page-colored ground', (
    tester,
  ) async {
    await _start(tester);
    await tester.pump();
    expect(find.byKey(_opening), findsOneWidget);
    final ground = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byKey(_opening),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(ground.color, ShioriTokens.light.bg, reason: 'the launch screen');
  });

  testWidgets('it is over within 1.2 seconds and 홈 is there', (tester) async {
    await _start(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(find.byKey(_opening), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('a tap skips it', (tester) async {
    await _start(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(_opening));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_opening), findsNothing);
  });

  testWidgets('reduced motion: no opening at all', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await _start(tester);
    await tester.pump();
    expect(find.byKey(_opening), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('coming back to the app does not show it again', (tester) async {
    await _start(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(_opening), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(_opening), findsNothing);
  });

  testWidgets('VoiceOver does not stop on it', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester);
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(_opening)).getSemanticsData().label,
      isEmpty,
    );
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('tests and previews (no firstLaunch) never see it', (
    tester,
  ) async {
    await _start(tester, firstLaunch: false);
    await tester.pump();
    expect(find.byKey(_opening), findsNothing);
  });
}
