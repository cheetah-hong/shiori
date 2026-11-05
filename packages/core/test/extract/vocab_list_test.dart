// V1, V7, V8, V9 and the other word-list rules on the synthetic word list
// without numbers (g10, tools/synthetic/make_general_pages.py): POS badges,
// blank reading cells, a headword read back from its kana and meaning, an
// optional prefix in brackets, and the page's OCR slips.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

Future<ExtractionResult> _g10({bool glossary = true}) async => GeneralExtractor(
  lexicon: generalLexicon(),
  koreanGlossary: glossary ? generalGlossary() : null,
).extract(await loadGeneralScan('g10'));

ExtractedWord _word(ExtractionResult r, String headword) => r.words.singleWhere(
  (w) => w.headword == headword,
  orElse: () => throw StateError(
    'no $headword in ${[for (final w in r.words) w.headword]}',
  ),
);

const _badgeTexts = ['명', '몀', '동', '동사', '부', '형', 'い형', 'な형', '니형', '⅓형'];

void main() {
  final truth = ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));
  final g10 = truth.pages.singleWhere((p) => p.fixture == 'g10');

  group('g10 scores', () {
    for (final glossary in [false, true]) {
      test('every printed word found, read and meant right, no extras '
          '(glossary: $glossary)', () async {
        final r = await _g10(glossary: glossary);
        final score = scoreExtractPage(g10, [
          for (final w in r.words) ScoredWord.fromExtracted(w),
        ]);
        // Printed for the score table in the test output.
        print(
          'g10 glossary $glossary: ${score.found}/${score.vocab} reading '
          '${score.readingsOk} meaning ${score.meanings.ok}/${score.meanings.of} '
          'extras ${score.extras} highWrong ${score.highWrong}',
        );
        // Without the glossary the misread 箱 has nothing to be read back
        // from: its kana はこ stays a word of its own.
        expect(score.found, glossary ? score.vocab : score.vocab - 1);
        expect(score.readingsOk, score.found);
        expect(score.meanings.ok, score.meanings.of);
        expect(score.highWrong, 0);
        expect(score.extras, glossary ? 0 : 1);
      });
    }
  });

  group('V1 POS badges', () {
    test('no meaning keeps a badge, read right or misread', () async {
      final r = await _g10();
      for (final w in r.words) {
        final m = w.meaning;
        if (m == null) continue;
        expect(
          _badgeTexts.any((b) => m.startsWith('$b ') || m.startsWith('$b.')),
          isFalse,
          reason: '${w.headword}: $m',
        );
      }
      expect(_word(r, '開ける').meaning, '열다');
      expect(_word(r, '机').meaning, '책상');
      expect(_word(r, '細い').meaning, '가늘다');
      expect(_word(r, '親切だ').meaning, '친절하다');
    });

    test('a badge is never a word or a fragment left for the tray', () async {
      final r = await _g10();
      final heads = {for (final w in r.words) w.headword};
      for (final b in _badgeTexts) {
        expect(heads, isNot(contains(b)));
      }
      for (final f in r.unpaired) {
        expect(_badgeTexts, isNot(contains(f.text.trim())), reason: '$f');
      }
    });

    test('the parts of speech agree with the badges', () async {
      final r = await _g10();
      expect(_word(r, '細い').partsOfSpeech, contains('adj-i'));
      expect(_word(r, '親切だ').partsOfSpeech, contains('adj-na'));
      expect(_word(r, '開ける').partsOfSpeech, contains('v1'));
      expect(_word(r, '机').partsOfSpeech, contains('n'));
    });

    test('a badge line the Japanese pass read as 8 and kanji at full '
        'confidence keeps its Korean meaning', () async {
      final r = await _g10();
      expect(_word(r, '窓').meaning, '창문');
      expect(r.words.map((w) => w.headword), isNot(contains('叉')));
    });
  });

  group('V7 blank reading cells', () {
    test('a flat dash beside a kana headword is no word and takes no '
        'meaning', () async {
      final r = await _g10();
      final heads = [for (final w in r.words) w.headword];
      expect(heads.where((h) => h == '一'), hasLength(1));
      for (final dash in ['ー', '-', '–']) {
        expect(heads, isNot(contains(dash)));
      }
      expect(_word(r, 'たくさん').meaning, '많이');
      expect(_word(r, 'やっと').meaning, '겨우, 간신히');
      expect(_word(r, 'きっと').meaning, '꼭, 분명히');
      for (final f in r.unpaired) {
        expect(['一', 'ー', '-', '–'], isNot(contains(f.text)), reason: '$f');
      }
    });

    test('a 一 as tall as the other headwords stays a word', () async {
      final r = await _g10();
      final one = _word(r, '一');
      expect(one.readings, ['いち']);
      expect(one.meaning, '하나, 일');
      expect(r.fragments[one.headwordFragmentId!].height, greaterThan(0.015));
    });
  });

  group('V8 a headword read back from its kana and meaning', () {
    test('竹 misread at 0.3 beside はこ and 상자 gives 箱, from the '
        'dictionary', () async {
      final r = await _g10();
      final box = _word(r, '箱');
      expect(box.readings, ['はこ']);
      expect(box.readingSource, FieldSource.photo);
      expect(box.meaning, '상자');
      expect(box.headwordSource, FieldSource.dictionary);
      expect(box.headwordNote, contains('사전 역조회'));
      final heads = r.words.map((w) => w.headword);
      expect(heads, isNot(contains('はこ')));
      expect(heads, isNot(contains('竹')));
    });

    test('a printed kana headword stays kana although its meaning has one '
        'kanji spelling', () async {
      final r = await _g10();
      final many = _word(r, 'たくさん');
      expect(many.headwordSource, FieldSource.photo);
      expect(r.words.map((w) => w.headword), isNot(contains('沢山')));
    });

    test('the evidence names the source and the reading stays the '
        "photo's", () async {
      final r = await _g10();
      final entry = _word(r, '箱').toCapturedEntry(fragments: r.fragments);
      final head = entry.evidence!.of(EntryField.headword)!;
      expect(head.source, FieldSource.dictionary);
      expect(head.note, contains('사전 역조회'));
      expect(
        entry.evidence!.of(EntryField.readings)!.source,
        FieldSource.photo,
      );
    });
  });

  group('V9 an optional prefix in brackets', () {
    test('(お)みやげ stays as printed and pairs on content', () async {
      final r = await _g10();
      final w = r.words.singleWhere((w) => w.headword.contains('みやげ'));
      expect(w.headword.replaceAll('（', '(').replaceAll('）', ')'), '(お)みやげ');
      expect(w.meaning, '선물, 기념품');
      expect(w.partsOfSpeech, contains('n'));
      expect(w.meaningLink!.signals, contains(PairSignal.koreanGloss));
    });
  });

  group('the other slips of the word list', () {
    test('a one-syllable Korean read over a 0.3 kanji headword does not '
        'hide it', () async {
      final r = await _g10();
      final garden = _word(r, '庭');
      expect(garden.readings, ['にわ']);
      expect(garden.meaning, '마당, 뜰');
      expect(r.words.map((w) => w.headword), isNot(contains('にわ')));
    });

    test('a reading the Korean pass read as (다 stays the reading', () async {
      final r = await _g10();
      final mirror = _word(r, '鏡');
      expect(mirror.readingSource, FieldSource.photo);
      expect(mirror.meaning, '거울');
    });

    test('katakana ニ in a kana-only headword becomes 二 when the reading '
        'beside it agrees', () async {
      final r = await _g10();
      final two = _word(r, '二つ');
      expect(two.readings, ['ふたつ']);
      expect(two.meaning, '두 개, 둘');
      expect(r.words.map((w) => w.headword), isNot(contains('ニつ')));
    });

    test('a headword read with a space inside is one word', () async {
      final r = await _g10();
      final accident = _word(r, '交通事故');
      expect(accident.readings, ['こうつうじこ']);
      expect(accident.meaning, '교통사고');
      final heads = r.words.map((w) => w.headword);
      expect(heads, isNot(contains('交通')));
      expect(heads, isNot(contains('事故')));
    });

    test('box glyphs read as 問 or コロロ are no words', () async {
      final r = await _g10();
      final heads = r.words.map((w) => w.headword);
      expect(heads, isNot(contains('問')));
      expect(heads, isNot(contains('コロロ')));
      expect(_word(r, '傘').meaning, '우산');
      expect(_word(r, '閉める').meaning, '닫다');
    });

    test('a legend line and a footer are no meanings', () async {
      for (final glossary in [false, true]) {
        final r = await _g10(glossary: glossary);
        for (final w in r.words) {
          expect(w.meaning ?? '', isNot(contains('=')), reason: w.headword);
          expect(w.meaning ?? '', isNot(contains('|')), reason: w.headword);
        }
        expect(_word(r, '整理').meaning, isNull);
      }
    });
  });
}
