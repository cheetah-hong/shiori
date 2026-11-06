// A synthetic sample on a simulator: the evidence of a sentence word's
// meaning filled from the glossary says so in Korean.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/korean_notes_screenshots_test.dart
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

  /// Pumps until [finder] shows up (unpacking takes a few seconds).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
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
    final key = card.evaluate().single.widget.key! as ValueKey<String>;
    return int.parse(key.value.substring('entry-'.length));
  }

  testWidgets('a filled meaning\'s evidence note', (tester) async {
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

    final sample = devSamples.singleWhere((s) => s.id == 's147');
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final row = find.text('${sample.page}쪽 · ${sample.layout}');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));

    final word = find.text('返品');
    await tester.scrollUntilVisible(word, 200);
    await Scrollable.ensureVisible(tester.element(word), alignment: 0.1);
    await tester.pumpAndSettle();
    final i = entryIndex('返品');
    await tester.tap(find.byKey(ValueKey('cell-$i-meaning')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('근거 조각'));
    expect(find.textContaining('사전 뜻'), findsWidgets);
    expect(find.textContaining('dictionary'), findsNothing);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('74_evidence_dictionary_meaning');
  });
}
