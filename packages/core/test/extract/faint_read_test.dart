// R1, R2, R5, R8: a pair held back only by a fragment read at the engine's
// lowest confidence (0.3) is high when the word's other pair backs it with
// content of its own — a dictionary reading beside a meaning the headword's
// kanji or Korean gloss names, both in their strong placement. Take away any
// one of those and it stays below high, with a note saying why. The other
// guards hold whatever the fragments' confidence, and lowering every line
// of the synthetic sets to 0.3 makes no wrong or extra entry high.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/confidence.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import 'support/confidence_fixtures.dart';
import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

/// Vision's lowest confidence as the device channel passes it on.
const double _faint = 0.30000001192092896;

/// The row's words, as the general pages' lexicon has them.
InMemoryLexicon _lexicon() => InMemoryLexicon(const [
  LexiconWord(
    id: 1237410,
    kanji: ['橋'],
    readings: ['はし'],
    pos: ['n'],
    priority: 5,
    nf: 5,
  ),
  LexiconWord(
    id: 1003430,
    readings: ['きっと'],
    pos: ['adv'],
    priority: 4,
    usuallyKana: true,
  ),
]);

Future<List<String>> Function(String, List<String>) _glosses(
  Map<String, List<String>> table,
) =>
    (headword, readings) async => table[headword] ?? const [];

/// One row: 橋, its reading and the Korean 다리, each at the confidence
/// given. [readingX]/[meaningY] move the reading and the meaning off their
/// strong placement; [gloss] off gives the meaning no content signal.
Future<ExtractedWord> _row({
  double head = 1.0,
  double kana = 1.0,
  double korean = 1.0,
  String reading = 'はし',
  double readingX = 0.16,
  double meaningY = 0.203,
  bool gloss = true,
}) async {
  final r =
      await GeneralExtractor(
        lexicon: _lexicon(),
        koreanGlosses: _glosses({
          if (gloss) '橋': ['다리'],
        }),
      ).extract(
        scan(
          ja: [
            line('橋', 0.10, 0.20, h: 0.022, c: head),
            line(reading, readingX, 0.201, c: kana),
          ],
          ko: [line('다리', 0.40, meaningY, h: 0.015, c: korean)],
        ),
      );
  return r.words.singleWhere((w) => w.headword == '橋');
}

/// [scan] with every line (of the passes chosen, or only those [only]
/// picks) read at the lowest confidence.
OcrScan _lowered(
  OcrScan scan, {
  bool ja = true,
  bool ko = true,
  bool Function(String text)? only,
}) {
  OcrPage low(OcrPage p, bool on) => !on
      ? p
      : OcrPage(
          lines: [
            for (final l in p.lines)
              OcrLine(
                text: l.text,
                x: l.x,
                y: l.y,
                width: l.width,
                height: l.height,
                confidence: only == null || only(l.text)
                    ? _faint
                    : l.confidence,
              ),
          ],
          engine: p.engine,
          languages: p.languages,
        );
  return OcrScan(
    japanese: low(scan.japanese, ja),
    korean: low(scan.korean, ko),
    turned: scan.turned,
  );
}

Future<ExtractScore> _score(
  ExtractTruth truth,
  Future<OcrScan> Function(String) load,
  GeneralExtractor extractor,
) async => ExtractScore([
  for (final page in truth.pages)
    scoreExtractPage(page, [
      for (final e in (await pageDraft(
        extractor,
        await load(page.fixture),
      )).entries)
        ScoredWord.fromCaptured(e),
    ]),
]);

/// Every synthetic set as the confidence tests read it.
List<(String, ExtractTruth, Future<OcrScan> Function(String), GeneralExtractor)>
_sets() => [
  for (final (name, glossary) in [
    ('none', null),
    ('stand-in', generalGlossary()),
    ('real senses', realGlossary()),
  ])
    (
      'general, glossary $name',
      ExtractTruth.fromJson(readGeneralJson('ground_truth.json')),
      loadGeneralScan,
      confidenceExtractor(generalLexicon(), glossary: glossary),
    ),
  (
    'android, real senses',
    ExtractTruth.fromJson(readGeneralJson('ground_truth_android.json')),
    loadGeneralScan,
    confidenceExtractor(generalLexicon(), glossary: realGlossary()),
  ),
  (
    'traps, real senses',
    trapTruth(),
    loadGeneralScan,
    confidenceExtractor(trapLexicon(), glossary: realGlossary()),
  ),
  for (final set in [synthetic, syntheticMlKit])
    (
      '${set.name}, real senses',
      set.truth,
      set.loadScan,
      confidenceExtractor(rowLexicon(), glossary: realReverseGlossary()),
    ),
];

void main() {
  group('R1 a faint fragment backed by the other pair', () {
    test('the row read plainly is high on both pairs, with no note', () async {
      final w = await _row();
      expect(w.readingLink?.confidence, PairConfidence.high);
      expect(w.meaningLink?.confidence, PairConfidence.high);
      expect(w.readingLink?.note, isNull);
      expect(w.meaningLink?.note, isNull);
    });

    for (final (what, head, kana, korean) in [
      ('the headword', _faint, 1.0, 1.0),
      ('the reading', 1.0, _faint, 1.0),
      ('the meaning', 1.0, 1.0, _faint),
      ('the headword and its reading', _faint, _faint, 1.0),
      ('the headword at 0.3 exactly', 0.3, 1.0, 1.0),
    ]) {
      test('$what at the lowest confidence: dictionary reading + gloss-named '
          'meaning, both placed strongly, is high', () async {
        final w = await _row(head: head, kana: kana, korean: korean);
        expect(w.readings, ['はし']);
        expect(w.meaning, '다리');
        expect(w.readingLink?.confidence, PairConfidence.high);
        expect(w.meaningLink?.confidence, PairConfidence.high);
        expect(w.pairConfidence, PairConfidence.high);
        expect(w.toCapturedEntry().evidence!.isHigh, isTrue);
      });
    }

    for (final (what, head, kana) in [
      ('headword', _faint, 1.0),
      ('reading', 1.0, _faint),
    ]) {
      group('the $what faint, one backing taken away', () {
        test('a reading the dictionary does not have: not high', () async {
          final w = await _row(head: head, kana: kana, reading: 'はじ');
          expect(w.readingLink?.confidence, isNot(PairConfidence.high));
          expect(w.pairConfidence, isNot(PairConfidence.high));
          expect(w.toCapturedEntry().evidence!.isHigh, isFalse);
        });

        test('the reading off its strong placement (far along the row): '
            'not high', () async {
          final w = await _row(head: head, kana: kana, readingX: 0.61);
          expect(w.readings, ['はし']);
          expect(w.readingLink?.confidence, isNot(PairConfidence.high));
          expect(w.pairConfidence, isNot(PairConfidence.high));
        });

        test('a meaning with no content signal (placement only): not '
            'high, the reading says the read was faint', () async {
          final w = await _row(head: head, kana: kana, gloss: false);
          expect(w.meaning, '다리');
          expect(w.readingLink?.confidence, isNot(PairConfidence.high));
          expect(w.readingLink?.note, faintReadNote);
          expect(w.pairConfidence, isNot(PairConfidence.high));
        });

        test('the meaning off its strong placement: not high', () async {
          final w = await _row(head: head, kana: kana, meaningY: 0.2285);
          expect(w.meaning, '다리');
          expect(w.readingLink?.confidence, isNot(PairConfidence.high));
          expect(w.pairConfidence, isNot(PairConfidence.high));
        });
      });
    }

    test('a kana word (no reading to back its meaning), read faint: not '
        'high, the meaning says the read was faint', () async {
      final r =
          await GeneralExtractor(
            lexicon: _lexicon(),
            koreanGlosses: _glosses({
              'きっと': ['꼭'],
            }),
          ).extract(
            scan(
              ja: [line('きっと', 0.10, 0.20, h: 0.022, c: _faint)],
              ko: [line('꼭', 0.40, 0.203, h: 0.015)],
            ),
          );
      final w = r.words.singleWhere((w) => w.headword == 'きっと');
      expect(w.meaning, '꼭');
      expect(w.readings, isEmpty);
      expect(w.meaningLink?.confidence, isNot(PairConfidence.high));
      expect(w.meaningLink?.note, faintReadNote);
    });

    test('neighbours read alike or printing the same meaning (g21, g23): '
        'not high with every line faint either', () async {
      final extractor = confidenceExtractor(
        trapLexicon(),
        glossary: realGlossary(),
      );
      final kanaOnly = RegExp(r'^[ぁ-ゖ]+$');
      for (final (fixture, words, field, only) in [
        // The readings faint (every line faint loses 橋's row altogether).
        ('g21', ['橋', '箸'], EntryField.readings, kanaOnly.hasMatch),
        ('g23', ['橋', '脚'], EntryField.meaning, null),
      ]) {
        final draft = await pageDraft(
          extractor,
          _lowered(await loadGeneralScan(fixture), only: only),
        );
        for (final h in words) {
          final e = entryOf(draft, h);
          expect(
            confidenceOf(e, field),
            isNot(PairConfidence.high),
            reason: '$fixture $h',
          );
          expect(e.evidence!.isHigh, isFalse, reason: '$fixture $h');
        }
      }
    });
  });

  group('R2 never high, whatever backs it', () {
    /// The read-back rows' words and glossary (as in the read-back tests).
    InMemoryLexicon backLexicon() => InMemoryLexicon(const [
      LexiconWord(
        id: 1585650,
        kanji: ['箱'],
        readings: ['はこ'],
        pos: ['n', 'suf', 'ctr'],
        priority: 5,
        nf: 9,
      ),
      LexiconWord(
        id: 1343460,
        kanji: ['暑い'],
        readings: ['あつい'],
        pos: ['adj-i'],
        priority: 6,
        nf: 34,
      ),
      LexiconWord(
        id: 1467720,
        kanji: ['熱い'],
        readings: ['あつい'],
        pos: ['adj-i'],
        priority: 5,
        nf: 14,
      ),
      LexiconWord(
        id: 1415870,
        kanji: ['沢山'],
        readings: ['たくさん'],
        pos: ['adj-no', 'adj-na', 'n', 'adv', 'n-suf'],
        priority: 6,
        nf: 43,
        usuallyKana: true,
      ),
    ]);
    MemoryKoreanGlossary backGlossary() => MemoryKoreanGlossary(
      {
        '箱': [
          ['상자'],
        ],
        '暑い': [
          ['덥다'],
        ],
        '熱い': [
          ['뜨겁다'],
        ],
        // Forwards only: the backward lookup finds no spelling.
        'たくさん': [
          ['많이'],
        ],
      },
      readings: {
        '箱': ['はこ'],
        '暑い': ['あつい'],
        '熱い': ['あつい'],
      },
    );
    OcrScan row(String left, String kana, String meaning) => scan(
      ja: [
        for (var i = 0; i < 3; i++) line('ロロロ', 0.15, 0.10 + 0.05 * i, c: 0.3),
        line(left, 0.20, 0.30, w: 0.019, h: 0.019, c: _faint),
        line(kana, 0.42, 0.30, c: _faint),
      ],
      ko: [line(meaning, 0.60, 0.30, h: 0.015, c: _faint)],
    );
    Future<ExtractedWord> wordOf(OcrScan s, String meaning) async =>
        (await GeneralExtractor(
          lexicon: backLexicon(),
          koreanGlossary: backGlossary(),
        ).extract(s)).words.singleWhere((w) => w.meaning == meaning);

    test('a headword read back from the dictionary', () async {
      final w = await wordOf(row('一', 'はこ', '상자'), '상자');
      expect(w.headword, '箱');
      expect(w.headwordSource, FieldSource.dictionary);
      expect(w.readingLink?.confidence, isNot(PairConfidence.high));
      expect(w.meaningLink?.confidence, isNot(PairConfidence.high));
    });

    test('a kana headword with headword candidates', () async {
      final w = await wordOf(row('己', 'あつい', '덥다, 뜨겁다'), '덥다, 뜨겁다');
      expect(w.headword, 'あつい');
      expect(w.headwordCandidates, isNotEmpty);
      expect(w.pairConfidence, isNot(PairConfidence.high));
    });

    test('a kana headword left where a headword was lost (a trace, '
        'nothing to read back)', () async {
      final w = await wordOf(row('己', 'たくさん', '많이'), '많이');
      expect(w.headword, 'たくさん');
      expect(w.headwordCandidates, isEmpty);
      expect(w.meaningLink?.confidence, isNot(PairConfidence.high));
    });
  });

  group('R5 the synthetic sets keep at least as many high entries', () {
    for (final (index, minHigh) in [
      (2, 33), // general, real senses
      (4, 2), // traps
      (5, 25), // word book
      (6, 13), // word book, ML Kit
    ]) {
      test('set $index: high >= $minHigh, nothing wrong or extra at '
          'high', () async {
        final (name, truth, load, extractor) = _sets()[index];
        final s = await _score(truth, load, extractor);
        print('$name: high ${s.high}');
        expect(s.high, greaterThanOrEqualTo(minHigh), reason: name);
        expect(s.highWrong, 0, reason: name);
        expect(s.extraHigh, 0, reason: name);
      });
    }
  });

  group('R8 every line read at the lowest confidence', () {
    for (final (passes, ja, ko) in [
      ('both passes', true, true),
      ('the Japanese pass', true, false),
      ('the Korean pass', false, true),
    ]) {
      test('$passes: no entry of any synthetic set is high and wrong, or '
          'high and extra', () async {
        for (final (name, truth, load, extractor) in _sets()) {
          final s = await _score(
            truth,
            (f) async => _lowered(await load(f), ja: ja, ko: ko),
            extractor,
          );
          print('$passes, $name: high ${s.high}');
          expect(s.highWrong, 0, reason: name);
          expect(s.extraHigh, 0, reason: name);
        }
      });
    }
  });
}
