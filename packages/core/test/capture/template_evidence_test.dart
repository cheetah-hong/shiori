// C5 (template side), C6: entries of a page read with the row template get
// the same kind of evidence as the general extractor's (source, pairing
// confidence, photo boxes), and their cell values stay exactly as the
// template pipeline gives them.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../extract/support/confidence_fixtures.dart';
import '../support/fixtures.dart';
import '../support/real_dictionary.dart';

CapturedEntry _row(
  String no,
  String headword,
  List<String> readings,
  String meaning, {
  List<EntryIssue> issues = const [],
}) => CapturedEntry(
  no: no,
  headword: headword,
  readings: readings,
  pos: PartOfSpeech.noun,
  meaning: meaning,
  issues: issues,
  ocrHeadword: headword,
);

Future<List<String>> Function(String, List<String>) _glosses(
  Map<String, List<String>> table,
) =>
    (headword, readings) async => table[headword] ?? const [];

final _lexicon = InMemoryLexicon([...rowPageWords, ...trapWords]);

/// 橋 is also in the lexicon (the general pages' entry, as JMdict has it).
final _withBridge = InMemoryLexicon([
  ...rowPageWords,
  ...trapWords,
  const LexiconWord(
    id: 1237410,
    kanji: ['橋'],
    readings: ['はし'],
    pos: ['n'],
    priority: 5,
    nf: 5,
  ),
]);

final _table = _glosses({
  '雨': ['비'],
  '雪': ['눈'],
  '橋': ['다리'],
  '脚': ['다리', '발'],
  '箸': ['젓가락'],
  '星': ['별'],
});

CapturedEntry _withoutEvidence(CapturedEntry e) => e.copyWith(evidence: null);

void main() {
  group('C6 the routed template pages', () {
    test('every entry carries evidence and the values are the template '
        'pipeline\'s', () async {
      final router = confidenceRouter(rowLexicon(), glossary: realGlossary());
      final plain = CapturePipeline.standard(glossary: realGlossary());
      for (final (set, fixtures) in [
        (synthetic, ['s010', 's011', 's140', 's147']),
        (syntheticMlKit, ['m011', 'm140']),
      ]) {
        for (final fixture in fixtures) {
          final scan = await set.loadScan(fixture);
          final routed = await router.fromScan(scan);
          final want = await plain.fromScan(scan);
          expect(routed.route!.route, CaptureRoute.template, reason: fixture);
          expect(
            [for (final e in routed.entries) _withoutEvidence(e)],
            want.entries,
            reason: fixture,
          );
          for (final e in routed.entries) {
            expect(e.evidence, isNotNull, reason: '$fixture ${e.no}');
            expect(e.evidence!.origin, WordOrigin.wordList);
          }
        }
      }
    });

    test('a read headword points at its place on the page', () async {
      final draft = await confidenceRouter(
        rowLexicon(),
        glossary: realGlossary(),
      ).fromScan(await synthetic.loadScan('s010'));
      for (final e in draft.entries.where((e) => e.headword.isNotEmpty)) {
        final head = e.evidence!.of(EntryField.headword)!;
        expect(head.source, FieldSource.photo, reason: e.headword);
        expect(head.boxes, isNotEmpty, reason: e.headword);
        for (final b in head.boxes) {
          expect(b.isEmpty, isFalse, reason: e.headword);
          expect(b.x >= 0 && b.right <= 1 && b.y >= 0 && b.bottom <= 1, isTrue);
        }
      }
    });

    test('s010: a headword the dictionary does not know keeps its reading '
        'below high', () async {
      final without = InMemoryLexicon([
        for (final w in rowPageWords)
          if (!w.kanji.contains('雲')) w,
      ]);
      final draft = await confidenceRouter(
        without,
        glossary: realGlossary(),
      ).fromScan(await synthetic.loadScan('s010'));
      final cloud = entryOf(draft, '雲');
      expect(confidenceOf(cloud, EntryField.readings), isNotNull);
      expect(
        confidenceOf(cloud, EntryField.readings),
        isNot(PairConfidence.high),
      );
      expect(cloud.evidence!.isHigh, isFalse);
      // A known one on the same page is high.
      expect(
        confidenceOf(entryOf(draft, '雨'), EntryField.readings),
        PairConfidence.high,
      );
    });

    test('s011: a meaning filled from the glossary says so and is not '
        'high', () async {
      final draft = await confidenceRouter(
        rowLexicon(),
        glossary: realGlossary(),
      ).fromScan(await synthetic.loadScan('s011'));
      final nose = entryOf(draft, '鼻');
      expect(nose.meaning, '코');
      final meaning = nose.evidence!.of(EntryField.meaning)!;
      expect(meaning.source, FieldSource.dictionary);
      expect(meaning.confidence, isNot(PairConfidence.high));
      expect(meaning.boxes, isEmpty);
      expect(nose.evidence!.isHigh, isFalse);
    });
  });

  group('cell rules', () {
    test('a plain row: the reading the dictionary has and a meaning the '
        'glossary gives are high; values and flags unchanged', () async {
      final rows = [
        _row('0001', '雨', const ['あめ'], '비'),
      ];
      final out = await withTemplateEvidence(
        rows,
        lexicon: _lexicon,
        glosses: _table,
      );
      expect([for (final e in out) _withoutEvidence(e)], rows);
      expect(
        confidenceOf(out.single, EntryField.readings),
        PairConfidence.high,
      );
      expect(confidenceOf(out.single, EntryField.meaning), PairConfidence.high);
      expect(
        out.single.evidence!.of(EntryField.readings)!.source,
        FieldSource.photo,
      );
      expect(out.single.evidence!.isHigh, isTrue);
    });

    test('C5 a printed reading the dictionary does not have: low, however '
        'sure the cell', () async {
      final out = await withTemplateEvidence(
        [
          _row('0001', '雨', const ['あま'], '비'),
        ],
        lexicon: _lexicon,
        glosses: _table,
      );
      expect(confidenceOf(out.single, EntryField.readings), PairConfidence.low);
      expect(out.single.evidence!.isHigh, isFalse);
    });

    test('a headword the dictionary does not know: the reading is not '
        'high', () async {
      final out = await withTemplateEvidence(
        [
          _row('0001', '雨傘具', const ['あまがさぐ'], '비'),
        ],
        lexicon: _lexicon,
        glosses: _table,
      );
      expect(
        confidenceOf(out.single, EntryField.readings),
        isNot(PairConfidence.high),
      );
      expect(out.single.evidence!.isHigh, isFalse);
    });

    test('neighbouring rows read alike (橋, 箸): neither reading is high; '
        'with a row between them they may be', () async {
      final near = await withTemplateEvidence(
        [
          _row('0001', '橋', const ['はし'], '다리'),
          _row('0002', '箸', const ['はし'], '젓가락'),
        ],
        lexicon: _withBridge,
        glosses: _table,
      );
      for (final e in near) {
        expect(
          confidenceOf(e, EntryField.readings),
          isNot(PairConfidence.high),
          reason: e.headword,
        );
      }
      final apart = await withTemplateEvidence(
        [
          _row('0001', '橋', const ['はし'], '다리'),
          _row('0002', '星', const ['ほし'], '별'),
          _row('0003', '箸', const ['はし'], '젓가락'),
        ],
        lexicon: _withBridge,
        glosses: _table,
      );
      expect(
        confidenceOf(apart.first, EntryField.readings),
        PairConfidence.high,
      );
      expect(
        confidenceOf(apart.last, EntryField.readings),
        PairConfidence.high,
      );
    });

    test('neighbouring rows print the same meaning (橋, 脚: 다리): neither '
        'meaning is high', () async {
      final out = await withTemplateEvidence(
        [
          _row('0001', '橋', const ['はし'], '다리'),
          _row('0002', '脚', const ['あし'], '다리'),
        ],
        lexicon: _withBridge,
        glosses: _table,
      );
      for (final e in out) {
        expect(
          confidenceOf(e, EntryField.meaning),
          isNot(PairConfidence.high),
          reason: e.headword,
        );
      }
    });

    test('a meaning with OCR debris is not high', () async {
      final out = await withTemplateEvidence(
        [
          _row('0001', '雨', const ['あめ'], '비, 4가'),
        ],
        lexicon: _lexicon,
        glosses: _table,
      );
      expect(
        confidenceOf(out.single, EntryField.meaning),
        isNot(PairConfidence.high),
      );
    });

    test('a meaning nothing on the page or in the glossary supports is not '
        'high; a flagged one is low', () async {
      final out = await withTemplateEvidence(
        [
          _row('0001', '雪', const ['ゆき'], '하양'),
          _row(
            '0002',
            '星',
            const ['ほし'],
            '별,',
            issues: const [EntryIssue.suspect(EntryField.meaning)],
          ),
        ],
        lexicon: _lexicon,
        glosses: _table,
      );
      expect(
        confidenceOf(out.first, EntryField.meaning),
        isNot(PairConfidence.high),
      );
      expect(confidenceOf(out.last, EntryField.meaning), PairConfidence.low);
    });

    test('an empty meaning or headword gives no pairing to rate', () async {
      final out = await withTemplateEvidence(
        [
          _row(
            '0001',
            '',
            const ['ひ'],
            '',
            issues: const [
              EntryIssue.missing(EntryField.headword),
              EntryIssue.missing(EntryField.meaning),
            ],
          ),
        ],
        lexicon: _lexicon,
        glosses: _table,
      );
      final e = out.single;
      expect(e.evidence!.of(EntryField.meaning), isNull);
      expect(e.evidence!.isHigh, isFalse);
      expect(_withoutEvidence(e).issues, hasLength(2));
    });
  });
}
