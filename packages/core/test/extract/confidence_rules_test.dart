// C3, C4, C5 (general side) and the guards around a high pairing: a reading
// another neighbouring headword would take too, a meaning a neighbour prints
// too, a printed reading the dictionary lacks, a meaning with OCR debris,
// a kanji headword with no reading, a headword the dictionary gave.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/real_dictionary.dart';
import 'support/confidence_fixtures.dart';
import 'support/extract_fixtures.dart';

Future<CaptureDraft> _trap(String fixture) async => pageDraft(
  confidenceExtractor(trapLexicon(), glossary: realGlossary()),
  await loadGeneralScan(fixture),
);

Future<List<String>> Function(String, List<String>) _glosses(
  Map<String, List<String>> table,
) =>
    (headword, readings) async => table[headword] ?? const [];

ExtractedWord _word(ExtractionResult r, String headword) =>
    r.words.firstWhere((w) => w.headword == headword);

void main() {
  group('C3 two headwords read alike', () {
    test('on neighbouring rows: neither reading pair is high (values '
        'right)', () async {
      final draft = await _trap('g21');
      for (final h in ['橋', '箸']) {
        final e = entryOf(draft, h);
        expect(e.readings, ['はし'], reason: h);
        expect(
          confidenceOf(e, EntryField.readings),
          isNot(PairConfidence.high),
          reason: h,
        );
        expect(e.evidence!.isHigh, isFalse, reason: h);
      }
    });

    test('far apart (out of each other\'s reach): the reading pairs may be '
        'high', () async {
      final draft = await _trap('g22');
      for (final h in ['橋', '箸']) {
        final e = entryOf(draft, h);
        expect(e.readings, ['はし'], reason: h);
        expect(
          confidenceOf(e, EntryField.readings),
          PairConfidence.high,
          reason: h,
        );
      }
    });
  });

  test('C4 two neighbours print the same Korean word: neither meaning pair '
      'is high', () async {
    final draft = await _trap('g23');
    for (final h in ['橋', '脚']) {
      final e = entryOf(draft, h);
      expect(e.meaning, '다리', reason: h);
      expect(
        confidenceOf(e, EntryField.meaning),
        isNot(PairConfidence.high),
        reason: h,
      );
      expect(e.evidence!.isHigh, isFalse, reason: h);
    }
  });

  group('C5 a printed reading the dictionary does not have', () {
    final extractor = GeneralExtractor(
      lexicon: trapLexicon(),
      koreanGlosses: _glosses({
        '橋': ['다리'],
      }),
    );

    test('right beside the headword: the reading is not high', () async {
      final r = await extractor.extract(
        scan(
          ja: [line('橋', 0.10, 0.20, h: 0.022), line('はさ', 0.16, 0.201)],
          ko: [line('다리', 0.40, 0.203, h: 0.015)],
        ),
      );
      final w = _word(r, '橋');
      expect(w.readingLink?.confidence, isNot(PairConfidence.high));
      expect(w.pairConfidence, isNot(PairConfidence.high));
    });

    test('in brackets after the headword: the reading is not high', () async {
      final r = await extractor.extract(
        scan(
          ja: [line('橋(はさ)', 0.10, 0.20, h: 0.022)],
          ko: [line('다리', 0.40, 0.203, h: 0.015)],
        ),
      );
      final w = _word(r, '橋');
      expect(w.readings, ['はさ']);
      expect(w.readingLink?.confidence, isNot(PairConfidence.high));
    });
  });

  test('a meaning with OCR debris beside the matching word is not high '
      '(two content signals agreeing on the word is not enough)', () async {
    final extractor = GeneralExtractor(
      lexicon: testLexicon(),
      koreanGlosses: _glosses({
        '図書館': ['도서관'],
      }),
    );
    final r = await extractor.extract(
      scan(
        ja: [line('図書館(としょかん)', 0.10, 0.20, h: 0.022)],
        ko: [line('도서관, 4가', 0.50, 0.203, h: 0.015)],
      ),
    );
    final w = _word(r, '図書館');
    expect(w.meaning, contains('4가'));
    expect(w.meaningLink?.confidence, isNot(PairConfidence.high));
    expect(w.toCapturedEntry().evidence!.isHigh, isFalse);
  });

  test('a kanji headword with no reading is never high', () async {
    final extractor = GeneralExtractor(
      koreanGlosses: _glosses({
        '図書館': ['도서관'],
      }),
    );
    final r = await extractor.extract(
      scan(
        ja: [line('図書館', 0.10, 0.20, h: 0.022)],
        ko: [line('도서관', 0.40, 0.203, h: 0.015)],
      ),
    );
    final w = _word(r, '図書館');
    expect(w.readings, isEmpty);
    expect(w.meaning, '도서관');
    expect(w.meaningLink?.confidence, isNot(PairConfidence.high));
    expect(w.toCapturedEntry().evidence!.isHigh, isFalse);
  });

  test('a headword the dictionary gave (not read on the page) is never '
      'high', () async {
    final extractor = GeneralExtractor(
      lexicon: InMemoryLexicon(rowPageWords),
      koreanGlosses: _glosses({
        '山': ['산'],
      }),
    );
    final r = await extractor.extract(
      scan(
        ja: [line('やま', 0.10, 0.20, h: 0.022)],
        ko: [line('산', 0.40, 0.203, h: 0.015)],
      ),
    );
    final w = _word(r, '山');
    expect(w.headwordSource, FieldSource.dictionary);
    expect(w.meaningLink?.confidence, isNot(PairConfidence.high));
    expect(w.pairConfidence, isNot(PairConfidence.high));
    expect(w.toCapturedEntry().evidence!.isHigh, isFalse);
  });

  test('a reading on the row and a gloss-matched meaning on the row: both '
      'high (the rules do raise a plain page)', () async {
    final extractor = GeneralExtractor(
      lexicon: trapLexicon(),
      koreanGlosses: _glosses({
        '橋': ['다리'],
      }),
    );
    final r = await extractor.extract(
      scan(
        ja: [line('橋', 0.10, 0.20, h: 0.022), line('はし', 0.16, 0.201)],
        ko: [line('다리', 0.40, 0.203, h: 0.015)],
      ),
    );
    final w = _word(r, '橋');
    expect(w.readings, ['はし']);
    expect(w.meaning, '다리');
    expect(w.readingLink?.confidence, PairConfidence.high);
    expect(w.meaningLink?.confidence, PairConfidence.high);
    expect(w.toCapturedEntry().evidence!.isHigh, isTrue);
  });

  test('read at the engine\'s lowest confidence (also as the device channel '
      'passes 0.3 on): not high', () async {
    final extractor = GeneralExtractor(
      lexicon: trapLexicon(),
      koreanGlosses: _glosses({
        '橋': ['다리'],
      }),
    );
    final r = await extractor.extract(
      scan(
        ja: [
          line('橋', 0.10, 0.20, h: 0.022),
          line('はし', 0.16, 0.201, c: 0.30000001192092896),
        ],
        ko: [line('다리', 0.40, 0.203, h: 0.015)],
      ),
    );
    final w = _word(r, '橋');
    expect(w.readings, ['はし']);
    expect(w.readingLink?.confidence, isNot(PairConfidence.high));
  });
}
