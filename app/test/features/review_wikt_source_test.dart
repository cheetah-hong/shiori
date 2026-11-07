// W5: on the review screen a meaning filled from the Wiktionary fallback is
// a guess (추정) like one from the Basic Korean Dictionary, and its evidence
// names 위키낱말사전 as where it came from.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/capture/review_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/glossary.dart';
import '../support/harness.dart';
import '../support/wikt.dart';

/// 鼻 as JMdict has it (1486720); 月道 made up (only the fallback knows it).
final _lexicon = InMemoryLexicon(const [
  LexiconWord(
    id: 1486720,
    kanji: ['鼻'],
    readings: ['はな'],
    pos: ['n'],
    priority: 5,
    nf: 8,
  ),
  LexiconWord(id: 9300001, kanji: ['月道'], readings: ['つきみち'], pos: ['n']),
]);

OcrLine _line(String t, double x, double y) => OcrLine(
  text: t,
  x: x,
  y: y,
  width: t.runes.length * 0.02,
  height: 0.02,
  confidence: 1,
);

/// Two word-list rows, neither meaning read.
final _scan = OcrScan(
  japanese: OcrPage(
    lines: [
      _line('鼻', 0.10, 0.10),
      _line('はな', 0.30, 0.10),
      _line('月道', 0.10, 0.20),
      _line('つきみち', 0.30, 0.20),
    ],
  ),
  korean: OcrPage(lines: const []),
);

void main() {
  testWidgets('月道 gets 달길, 월로 from 위키낱말사전, marked 추정', (tester) async {
    usePhoneSize(tester);
    final krdict = openMiniKrdict();
    final wikt = openMiniWikt();
    addTearDown(krdict.close);
    addTearDown(wikt.close);
    final draft = (await tester.runAsync(
      () => pageDraft(
        GeneralExtractor(
          lexicon: _lexicon,
          koreanGlossary: krdict,
          meaningFallback: wikt,
        ),
        _scan,
      ),
    ))!;
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: draft)));
    await tester.pumpAndSettle();

    expect(find.text('코'), findsOneWidget);
    expect(find.text('달길, 월로'), findsOneWidget);
    expect(find.text('뜻 없음'), findsNothing);
    expect(
      find.byKey(const ValueKey('mark-meaning-inferred')),
      findsNWidgets(2),
    );

    await tester.tap(find.byKey(const ValueKey('cell-1-meaning')));
    await tester.pumpAndSettle();
    expect(find.text('근거 조각'), findsOneWidget);
    expect(find.textContaining('위키낱말사전'), findsOneWidget);
  });

  testWidgets('a meaning from the Basic Korean Dictionary does not name '
      'Wiktionary', (tester) async {
    usePhoneSize(tester);
    final krdict = openMiniKrdict();
    final wikt = openMiniWikt();
    addTearDown(krdict.close);
    addTearDown(wikt.close);
    final draft = (await tester.runAsync(
      () => pageDraft(
        GeneralExtractor(
          lexicon: _lexicon,
          koreanGlossary: krdict,
          meaningFallback: wikt,
        ),
        _scan,
      ),
    ))!;
    await tester.pumpWidget(screen(TestBlocks(), ReviewScreen(draft: draft)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cell-0-meaning')));
    await tester.pumpAndSettle();
    expect(find.text('근거 조각'), findsOneWidget);
    expect(find.textContaining('위키낱말사전'), findsNothing);
    expect(find.textContaining('사전 뜻'), findsOneWidget);
  });
}
