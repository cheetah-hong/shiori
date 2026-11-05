// V2: entries with an example box (g11, tools/synthetic/make_general_pages.py):
// the sentence that holds the headword (or a conjugated form) is its example
// with the translation printed under it; furigana over the sentence are no
// words; the translation is no meaning; the other words of the sentence come
// out as sentence words, merged with a headword printed on the page.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

Future<ExtractionResult> _g11({bool glossary = true}) async => GeneralExtractor(
  lexicon: generalLexicon(),
  koreanGlossary: glossary ? generalGlossary() : null,
).extract(await loadGeneralScan('g11'));

const _translations = ['짐을 친구 집에 보냈습니다.', '방을 정리하고 나서 외출합니다.', '여행 준비를 했습니다.'];

const _furigana = ['にもつ', 'ともだち', 'へや', 'りょこう', 'じゅんび'];

void main() {
  final truth = ExtractTruth.fromJson(readGeneralJson('ground_truth.json'));
  final g11 = truth.pages.singleWhere((p) => p.fixture == 'g11');

  for (final glossary in [false, true]) {
    test('g11 scores: every entry and sentence word, no extras '
        '(glossary: $glossary)', () async {
      final r = await _g11(glossary: glossary);
      final score = scoreExtractPage(g11, [
        for (final w in r.words) ScoredWord.fromExtracted(w),
      ]);
      // Printed for the score table in the test output.
      print(
        'g11 glossary $glossary: ${score.found}/${score.vocab} meaning '
        '${score.meanings.ok}/${score.meanings.of} sentence '
        '${score.sentenceWords.ok}/${score.sentenceWords.of} extras '
        '${score.extras} highWrong ${score.highWrong}',
      );
      expect(score.found, score.vocab);
      expect(score.readingsOk, score.found);
      expect(score.meanings.ok, score.meanings.of);
      expect(score.sentenceWords.ok, score.sentenceWords.of);
      expect(score.extras, 0);
      expect(score.highWrong, 0);
    });
  }

  test('the example under an entry is its example, with the translation '
      'below it', () async {
    final r = await _g11();
    final send = r.words.singleWhere((w) => w.headword == '届ける');
    expect(send.origin, WordOrigin.wordList);
    expect(send.meaning, '보내다, 배달하다');
    expect(
      send.example,
      const WordExample(ja: '荷物を友達の家に届けました。', ko: '짐을 친구 집에 보냈습니다.'),
    );
    final tidy = r.words.singleWhere((w) => w.headword == '片付ける');
    expect(tidy.example?.ja, '部屋を片付けてから出かけます。');
    expect(tidy.example?.ko, '방을 정리하고 나서 외출합니다.');
  });

  test('a translation is never a meaning', () async {
    final r = await _g11();
    for (final w in r.words) {
      expect(_translations, isNot(contains(w.meaning)), reason: w.headword);
    }
  });

  test('the other words of a sentence are sentence words with the '
      'example', () async {
    final r = await _g11();
    for (final h in ['荷物', '友達', '家']) {
      final w = r.words.singleWhere((w) => w.headword == h);
      expect(w.origin, WordOrigin.sentence, reason: h);
      expect(w.example?.ko, '짐을 친구 집에 보냈습니다.', reason: h);
    }
  });

  test(
    'a headword printed on the page and in its sentence is one word',
    () async {
      final r = await _g11();
      for (final h in ['届ける', '片付ける', '準備']) {
        expect(r.words.where((w) => w.headword == h), hasLength(1), reason: h);
      }
      expect(
        r.words.singleWhere((w) => w.headword == '準備').example?.ko,
        '여행 준비를 했습니다.',
      );
    },
  );

  test('furigana over a sentence are no words and wait in no tray', () async {
    final r = await _g11();
    final heads = r.words.map((w) => w.headword);
    for (final f in _furigana) {
      expect(heads, isNot(contains(f)));
      expect(r.unpaired.map((u) => u.text), isNot(contains(f)));
    }
  });

  test('a meaning on two lines (a bracketed note, then the meaning) is one '
      'meaning', () async {
    final r = await _g11();
    final tidy = r.words.singleWhere((w) => w.headword == '片付ける');
    expect(tidy.meaning, '정리하다, 치우다');
    expect(tidy.meaningNotes, ['물건을 제자리에']);
  });

  test('a box heading is no meaning', () async {
    final r = await _g11();
    for (final w in r.words) {
      expect(w.meaning ?? '', isNot(contains('[문형]')), reason: w.headword);
    }
  });
}
