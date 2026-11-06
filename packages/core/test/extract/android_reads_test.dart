// A1, A2, E, F, I and the trace gate on the synthetic pages of the Android
// channel's slips (tools/synthetic/make_general_pages.py, answers in
// ground_truth_android.json): badges glued to the meaning, a full stop read
// after it, a look-alike kanji, header bands, a vertical side tab, the next
// page cut at the edge, a list of kanji words only, and kana whose headword
// OCR lost.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

Future<ExtractionResult> _page(String fixture, {bool glossary = true}) =>
    loadGeneralScan(fixture).then(
      (scan) => GeneralExtractor(
        lexicon: generalLexicon(),
        koreanGlossary: glossary ? generalGlossary() : null,
      ).extract(scan),
    );

ExtractedWord _word(ExtractionResult r, String headword) => r.words.singleWhere(
  (w) => w.headword == headword,
  orElse: () => throw StateError(
    'no $headword in ${[for (final w in r.words) w.headword]}',
  ),
);

Set<String> _heads(ExtractionResult r) => {for (final w in r.words) w.headword};

PageExtractScore _score(ExtractionResult r, String fixture) {
  final truth = ExtractTruth.fromJson(
    readGeneralJson('ground_truth_android.json'),
  );
  return scoreExtractPage(
    truth.pages.singleWhere((p) => p.fixture == fixture),
    [for (final w in r.words) ScoredWord.fromExtracted(w)],
  );
}

void main() {
  group('g30 scores', () {
    test('every word found, read and meant right, no extras', () async {
      final r = await _page('g30');
      final s = _score(r, 'g30');
      print(
        'g30: ${s.found}/${s.vocab} reading ${s.readingsOk} meaning '
        '${s.meanings.ok}/${s.meanings.of} extras ${s.extras} '
        'highWrong ${s.highWrong} extraHigh ${s.extraHigh}',
      );
      expect(s.found, s.vocab, reason: '${s.mistakes}');
      expect(s.readingsOk, s.found, reason: '${s.mistakes}');
      expect(s.meanings.ok, s.meanings.of, reason: '${s.mistakes}');
      expect(s.extras, 0, reason: '${s.mistakes}');
      expect(s.highWrong, 0, reason: '${s.mistakes}');
      expect(s.extraHigh, 0, reason: '${s.mistakes}');
    });
  });

  group('A1 badges glued to the meaning', () {
    test('a badge before Korean the content names goes', () async {
      final r = await _page('g30');
      expect(_word(r, '写真').meaning, '사진');
      expect(_word(r, '出発').meaning, '출발하다');
    });

    test('a two-letter badge (い형, な형) goes, read as one Korean run', () async {
      final r = await _page('g30');
      expect(_word(r, '新しい').meaning, '새롭다');
      expect(_heads(r), isNot(contains('い')));
      expect(r.unpaired.map((f) => f.text), isNot(contains('い')));
    });

    test('a badge before a number goes', () async {
      final r = await _page('g30');
      expect(_word(r, '三').meaning, '3, 삼');
    });

    test('a meaning that starts with a badge syllable stays whole', () async {
      final r = await _page('g30');
      // 명함: the glossary names the whole word.
      expect(_word(r, '名刺').meaning, '명함');
      // 동전: nothing names either reading; one badge syllable before Korean
      // stays as printed.
      expect(_word(r, '小銭').meaning, '동전');
    });

    test('without the glossary the glued badges still go', () async {
      final r = await _page('g30', glossary: false);
      expect(_word(r, '写真').meaning, '사진');
      expect(_word(r, '新しい').meaning, '새롭다');
      expect(_word(r, '三').meaning, '3, 삼');
      expect(_word(r, '小銭').meaning, '동전');
    });

    test('a stripped badge marks the read as corrected', () async {
      final r = await _page('g30');
      expect(_word(r, '写真').readQuality.corrected, isTrue);
      expect(_word(r, '名刺').readQuality.corrected, isFalse);
    });
  });

  group('A2 a full stop after the meaning', () {
    test('a short dictionary-form predicate is a meaning', () async {
      final r = await _page('g30');
      expect(_word(r, '待つ').meaning, '기다리다');
      expect(_word(r, '起きる').meaning, '일어나다, 잠이 깨다');
    });

    test('a sentence in the past tense is no meaning', () async {
      final r = await _page('g30');
      for (final w in r.words) {
        expect(w.meaning, isNot('비가 왔다'), reason: w.headword);
      }
      final left = r.unpaired.where((f) => f.text.contains('비가'));
      expect(left.single.kind, FragmentKind.koreanSentence);
    });

    test('translations of example sentences stay translations', () async {
      final r = await _page('g11');
      final w = _word(r, '届ける');
      expect(w.example?.ko, '짐을 친구 집에 보냈습니다.');
      expect(w.meaning, '보내다, 배달하다');
    });
  });

  group('E a look-alike kanji fixed by the reading beside it', () {
    test('one dictionary spelling of the kana differs by one kanji', () async {
      final r = await _page('g30');
      final w = _word(r, '休む');
      expect(w.readings, ['やすむ']);
      expect(w.meaning, '쉬다');
      expect(w.headwordNote, contains('글자 보정'));
      expect(w.headwordSource, FieldSource.photo);
      expect(_heads(r), isNot(contains('体む')));
      expect(_heads(r), isNot(contains('やすむ')));
    });

    test('two such spellings: nothing is fixed', () async {
      final lexicon = InMemoryLexicon(const [
        LexiconWord(
          id: 1516930,
          kanji: ['方'],
          readings: ['ほう'],
          pos: ['n'],
          priority: 5,
          nf: 12,
        ),
        LexiconWord(
          id: 1584460,
          kanji: ['万'],
          readings: ['まん', 'よろず'],
          pos: ['num', 'n', 'adj-no', 'adv'],
          priority: 4,
        ),
        LexiconWord(
          id: 2405850,
          kanji: ['満'],
          readings: ['まん'],
          pos: ['n', 'pref'],
        ),
      ]);
      final page = scan(
        ja: [
          line('方', 0.20, 0.30, w: 0.022, h: 0.019, c: 0.7),
          line('まん', 0.42, 0.30, w: 0.037, h: 0.016, c: 0.8),
        ],
        ko: [line('가득', 0.60, 0.302, w: 0.021, h: 0.014, c: 0.6)],
      );
      final r = await GeneralExtractor(lexicon: lexicon).extract(page);
      for (final w in r.words) {
        expect(w.headwordNote ?? '', isNot(contains('글자 보정')), reason: '$w');
      }
      expect(_heads(r), isNot(contains('万')));
      expect(_heads(r), isNot(contains('満')));
    });

    test('a headword the kana reads is left alone', () async {
      final r = await _page('g30');
      expect(_word(r, '待つ').headwordNote, isNull);
    });
  });

  group('I one kana', () {
    test('one kana paired by place alone is no word', () async {
      final r = await _page('g30');
      expect(_heads(r), isNot(contains('ね')));
    });
  });

  group('A2 bands, side tabs and the page edge', () {
    test('the header band right above the list is no meaning', () async {
      final r = await _page('g31');
      expect(_word(r, '弁当').meaning, isNull);
      for (final w in r.words) {
        expect(w.meaning ?? '', isNot(contains('2단계')), reason: w.headword);
      }
    });

    test('a vertical side tab is no meaning', () async {
      final r = await _page('g31');
      expect(_word(r, '地図').meaning, isNull);
      for (final w in r.words) {
        expect(w.meaning ?? '', isNot(contains('단어 모음')), reason: w.headword);
      }
    });

    test('the next page cut at the edge gives no words, but stays in the '
        'tray', () async {
      final r = await _page('g31');
      expect(_heads(r), isNot(contains('雪')));
      expect(_heads(r), isNot(contains('星')));
      final tray = {for (final f in r.unpaired) f.text};
      expect(tray, containsAll(['雪', '星']));
    });

    test('a word left in the tray becomes a new word in one step', () async {
      final r = await _page('g31');
      final snow = r.unpaired.firstWhere((f) => f.text == '雪');
      final entry = entryFromFragment(snow);
      expect(entry.headword, '雪');
    });

    test(
      'a kanji the Japanese pass read in a meaning line is no word',
      () async {
        final r = await _page('g31');
        expect(_heads(r), isNot(contains('合')));
        expect(_word(r, '五').meaning, '5, 오');
      },
    );

    test('g31 score: only the headword OCR lost is missed', () async {
      final r = await _page('g31');
      final s = _score(r, 'g31');
      print(
        'g31: ${s.found}/${s.vocab} meaning ${s.meanings.ok}/${s.meanings.of} '
        'extras ${s.extras} extraHigh ${s.extraHigh} ${s.mistakes}',
      );
      expect(s.found, s.vocab - 1);
      expect(s.mistakes, contains('MISS 鍵'));
      expect(s.meanings.ok, s.meanings.of);
      expect(s.extras, 1);
      expect(s.mistakes, contains('EXTRA かぎ'));
      expect(s.highWrong, 0);
      expect(s.extraHigh, 0);
    });
  });

  group('F words with nothing paired', () {
    test('a list of kanji words only keeps every word', () async {
      final r = await _page('g32');
      final s = _score(r, 'g32');
      expect(s.found, s.vocab, reason: '${s.mistakes}');
      expect(s.readingsOk, s.found, reason: '${s.mistakes}');
      expect(s.extras, 0, reason: '${s.mistakes}');
      for (final w in r.words) {
        expect(w.readingSource, FieldSource.dictionary, reason: w.headword);
      }
    });
  });

  group('the trace gate', () {
    test('kana where the headword was lost (marks, then an empty headword '
        'cell) is never high', () async {
      final r = await _page('g31');
      final w = _word(r, 'かぎ');
      expect(w.meaning, '열쇠');
      expect(w.pairConfidence, isNot(PairConfidence.high));
      expect(w.meaningLink?.note, contains('표제어 자리'));
    });

    test('kana beside a failed headword read that was not read back is '
        'never high', () async {
      final r = await _page('g31');
      final w = _word(r, 'ねじ');
      expect(w.meaning, '나사');
      expect(w.pairConfidence, isNot(PairConfidence.high));
      expect(w.meaningLink?.note, contains('표제어 자리'));
    });

    test('a kana headword printed beside its checkbox keeps its '
        'confidence', () async {
      final r = await _page('g10');
      final w = _word(r, 'やっと');
      expect(w.meaningLink?.note ?? '', isNot(contains('표제어 자리')));
    });
  });
}
