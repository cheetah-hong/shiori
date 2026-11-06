// The review screen with the Korean glossary plugged in: a meaning the page
// did not give is filled from the dictionary and shown as a guess (추정).
// The word extractor fills it for a dictionary word, so the two words of the
// made-up rows come with their JMdict values.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/glossary.dart';
import '../support/harness.dart';

/// 鼻 and 指 as JMdict has them (entries 1486720, 1309650).
final _lexicon = InMemoryLexicon(const [
  LexiconWord(
    id: 1486720,
    kanji: ['鼻'],
    readings: ['はな'],
    pos: ['n'],
    priority: 5,
    nf: 8,
  ),
  LexiconWord(
    id: 1309650,
    kanji: ['指'],
    readings: ['ゆび'],
    pos: ['n'],
    priority: 5,
    nf: 6,
  ),
]);

OcrLine _line(String t, double x, double y) => OcrLine(
  text: t,
  x: x,
  y: y,
  width: t.runes.length * 0.02,
  height: 0.02,
  confidence: 1,
);

/// Two word-list rows; the first one's meaning was not read.
const _ja = ['鼻', 'はな', '指', 'ゆび'];
final _scan = OcrScan(
  japanese: OcrPage(
    lines: [
      _line(_ja[0], 0.10, 0.10),
      _line(_ja[1], 0.30, 0.10),
      _line(_ja[2], 0.10, 0.20),
      _line(_ja[3], 0.30, 0.20),
    ],
  ),
  korean: OcrPage(lines: [_line('손가락', 0.50, 0.20)]),
);

Future<CaptureDraft> _draft({KoreanGlossary? glossary}) => pageDraft(
  GeneralExtractor(lexicon: _lexicon, koreanGlossary: glossary),
  _scan,
);

void main() {
  testWidgets('鼻 read without its meaning gets 코, marked 추정', (tester) async {
    usePhoneSize(tester);
    final glossary = openMiniKrdict();
    addTearDown(glossary.close);
    final draft = (await tester.runAsync(() => _draft(glossary: glossary)))!;
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: draft)));
    await tester.pumpAndSettle();

    expect(find.text('코'), findsOneWidget);
    expect(find.text('손가락'), findsOneWidget);
    expect(find.text('뜻 없음'), findsNothing);
    expect(find.byKey(const ValueKey('mark-meaning-inferred')), findsOneWidget);
  });

  testWidgets('without the glossary the same meaning is flagged as missing', (
    tester,
  ) async {
    usePhoneSize(tester);
    final draft = (await tester.runAsync(_draft))!;
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: draft)));
    await tester.pumpAndSettle();

    expect(find.text('뜻 없음'), findsOneWidget);
    expect(find.text('손가락'), findsOneWidget);
  });
}
