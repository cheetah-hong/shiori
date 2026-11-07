// The Wiktionary fallback glossary on a simulator: its card on the 정보
// screen, its licence entry, and on the review screen a meaning the Basic
// Korean Dictionary has none for filled from it, with its evidence, the
// assets unpacked on the device.
//
//   cd app && flutter drive -d <simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/wikt_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Needs app/assets/dict/ko-glossary.*
// and wikt-glossary.* (tools/dict/build_ko_glossary.py,
// build_wikt_glossary.py). Uses the synthetic sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (unpacking takes a few seconds).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('위키낱말사전: card, licence, a filled meaning and its evidence', (
    tester,
  ) async {
    // main() registers the data licences; this test pumps the app itself.
    registerGlossaryLicense();
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));

    // 정보: the card under the Basic Korean Dictionary's.
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    final card = find.text('위키낱말사전');
    await tester.scrollUntilVisible(card, 200);
    await waitFor(tester, card);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -40));
    await shot(tester, '90_about_wikt');

    // The licence page entry.
    await tester.scrollUntilVisible(find.text('오픈소스 라이선스'), 300);
    await tester.tap(find.text('오픈소스 라이선스'));
    await tester.pumpAndSettle();
    // The licence list loads in the background; then scroll it to the entry.
    await waitFor(tester, find.text('시오리'));
    final entry = find.text('위키낱말사전');
    for (var i = 0; i < 60 && entry.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(entry.first);
    await tester.pumpAndSettle();
    await tester.tap(entry.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('CC BY-SA'), findsWidgets);
    await shot(tester, '91_license_wikt');
    // Back to the home screen: the licence, the licence list, 정보.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    // DAY 20: the sentence word 大阪 has no Basic Korean Dictionary meaning.
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final page = find.text('DAY 20 여행·교통').last;
    await tester.ensureVisible(page);
    await tester.pumpAndSettle();
    await tester.tap(page);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
    // The meaning cell 오사카 (the sentences say 오사카까지, not 오사카).
    final osaka = find.text('오사카');
    await tester.scrollUntilVisible(osaka, 200);
    await tester.ensureVisible(osaka.first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(find.text('大阪'), findsWidgets);
    await shot(tester, '92_review_wikt_meaning');

    // Its evidence names where the meaning came from.
    await tester.tap(osaka.first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('근거 조각'));
    expect(find.textContaining('위키낱말사전'), findsOneWidget);
    await shot(tester, '93_evidence_wikt');
  });
}
