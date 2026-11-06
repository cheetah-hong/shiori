// M4: the review screen offers at most four other senses of a meaning the
// dictionary filled, in the glossary's order, and the one picked is the
// meaning saved. Made-up word 風道 (かざみち) with six senses of one level in
// the glossary fixture (tools/dict/testdata/krdict_sample.json).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/glossary.dart';
import '../support/harness.dart';

final _lexicon = InMemoryLexicon(const [
  LexiconWord(id: 9200001, kanji: ['風道'], readings: ['かざみち'], pos: ['n']),
]);

OcrLine _line(String t, double x, double y) => OcrLine(
  text: t,
  x: x,
  y: y,
  width: t.runes.length * 0.02,
  height: 0.02,
  confidence: 1,
);

/// One word-list row whose meaning was not read.
final _scan = OcrScan(
  japanese: OcrPage(
    lines: [_line('風道', 0.10, 0.10), _line('かざみち', 0.30, 0.10)],
  ),
  korean: const OcrPage(lines: []),
);

const _shown = ['바람골', '샛바람길', '갈바람길', '하늬길'];

Finder _chip(String meaning) =>
    find.byKey(ValueKey('candidate-0-meaning-$meaning'));

Future<TestBlocks> _pump(WidgetTester tester) async {
  usePhoneSize(tester);
  final glossary = openMiniKrdict();
  addTearDown(glossary.close);
  final draft = (await tester.runAsync(
    () => pageDraft(
      GeneralExtractor(lexicon: _lexicon, koreanGlossary: glossary),
      _scan,
    ),
  ))!;
  final blocks = TestBlocks();
  await tester.pumpWidget(screen(blocks, ReviewScreen(draft: draft)));
  await tester.pumpAndSettle();
  return blocks;
}

void main() {
  testWidgets('the first sense is the meaning and the next four are chips, '
      'in order', (tester) async {
    await _pump(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cell-0-meaning')),
        matching: find.text('바람길'),
      ),
      findsOneWidget,
    );
    for (final m in _shown) {
      expect(_chip(m), findsOneWidget, reason: m);
    }
    expect(_chip('마파람길'), findsNothing, reason: 'a sixth sense is not shown');
    final xs = [for (final m in _shown) tester.getTopLeft(_chip(m))];
    for (var i = 1; i < xs.length; i++) {
      final before = xs[i - 1], here = xs[i];
      expect(
        here.dy > before.dy || (here.dy == before.dy && here.dx > before.dx),
        isTrue,
        reason: '${_shown[i]} after ${_shown[i - 1]}',
      );
    }
  });

  testWidgets('a picked sense is the meaning that is saved', (tester) async {
    final blocks = await _pump(tester);

    await tester.tap(_chip('갈바람길'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cell-0-meaning')),
        matching: find.text('갈바람길'),
      ),
      findsOneWidget,
    );
    expect(_chip('바람길'), findsOneWidget, reason: 'the pick can be undone');

    await tester.tap(find.text('단어 1개 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('만들고 추가'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    final playlist = (await blocks.library.playlists()).single;
    final words = await blocks.library.words(playlistId: playlist.id);
    expect(words.map((w) => (w.headword, w.meaning)), [('風道', '갈바람길')]);
  });
}
