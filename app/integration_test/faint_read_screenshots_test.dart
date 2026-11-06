// Synthetic word-book samples on a simulator: a kana headword beside a
// ticked checkbox gets no headword candidates, and a pair held back by a
// faintly read fragment says so on its evidence piece.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/faint_read_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Needs app/assets/dict/ (JMdict and
// the Korean glossary). Uses the synthetic sample pages only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
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

  Future<void> openSample(WidgetTester tester, DevSample sample) async {
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final row = find.text('${sample.page}쪽 · ${sample.layout}');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
  }

  /// The index of the review card that shows [headword].
  int entryIndex(String headword) {
    final card = find.ancestor(
      of: find.text(headword),
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('entry-'),
      ),
    );
    final key = _widget(card).key! as ValueKey<String>;
    return int.parse(key.value.substring('entry-'.length));
  }

  testWidgets('checkbox column and a faint read', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    // The dictionaries unpack in the background; the 정보 screen waits.
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('JMdict 날짜'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // ちょっと beside a ticked box row: no headword candidates.
    await openSample(tester, devSamples.first);
    final kana = find.text('ちょっと');
    await tester.scrollUntilVisible(kana, 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await shot(tester, '67_review_checkbox_no_candidates');
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    // 到着時刻 (its reading read faintly, its meaning by placement only).
    await openSample(tester, devSamples.singleWhere((s) => s.id == 's140'));
    final word = find.text('到着時刻');
    await tester.scrollUntilVisible(word, 200);
    // The card's top a little below the app bar.
    await Scrollable.ensureVisible(tester.element(word), alignment: 0.1);
    await shot(tester, '68_review_faint_read');
    final i = entryIndex('到着時刻');
    await tester.tap(find.byKey(ValueKey('cell-$i-readings')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('근거 조각'));
    expect(find.textContaining('글자가 흐릿하게 읽힘'), findsOneWidget);
    await shot(tester, '69_evidence_faint_read');
  });
}

/// The widget [finder] finds (one).
Widget _widget(Finder finder) => finder.evaluate().single.widget;
