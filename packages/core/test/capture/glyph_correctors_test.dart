// The correctors for OCR slips that need no page geometry: reading look-alikes,
// the 동 badge read as 8, periods between Korean words, POS guesses and cut
// meanings. Examples use synthetic set words.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:test/test.dart';

CapturedEntry entry({
  String headword = '乗り換える',
  List<String> readings = const ['のりかえる'],
  PartOfSpeech? pos = PartOfSpeech.verb,
  String meaning = '갈아타다',
}) => CapturedEntry(
  no: '1211',
  headword: headword,
  readings: readings,
  pos: pos,
  meaning: meaning,
  important: false,
);

void main() {
  group('ReadingLookalikeCorrector', () {
    const c = ReadingLookalikeCorrector();

    test('リ in a hiragana reading becomes り, and is shown', () async {
      final e = await c.correct(entry(readings: ['のリかえる']));
      expect(e.readings, ['のりかえる']);
      expect(e.issues.single.code, 'readings:corrected');
      expect(e.issues.single.note, 'のリかえる → のりかえる');
    });

    test('a katakana reading stays katakana', () async {
      final e = entry(readings: ['レシート']);
      expect(await c.correct(e), same(e));
    });

    test('a reading that would stay mixed is left alone', () async {
      final e = entry(readings: ['リスと']);
      expect((await c.correct(e)).readings, ['リスと']);
    });

    test('long vowel marks may stay', () async {
      final e = await c.correct(entry(readings: ['ベーかり']));
      expect(e.readings, ['べーかり']);
    });
  });

  group('BadgeMisreadCorrector', () {
    const c = BadgeMisreadCorrector();

    test('a leading 8 is the 동 badge', () async {
      final e = await c.correct(entry(pos: null, meaning: '8 흔들리다'));
      expect((e.pos, e.meaning), (PartOfSpeech.verb, '흔들리다'));
      expect(e.issues.single.code, 'pos:corrected');
    });

    test('an 8 badge with nothing after it', () async {
      final e = await c.correct(entry(pos: null, meaning: '8'));
      expect((e.pos, e.meaning), (PartOfSpeech.verb, ''));
    });

    test('a meaning that starts with a number is not a badge', () async {
      for (final m in ['80년대', '8시']) {
        final e = entry(pos: null, meaning: m);
        expect(await c.correct(e), same(e), reason: m);
      }
    });

    test('a POS read from a real badge is kept', () async {
      final e = entry(pos: PartOfSpeech.noun, meaning: '8 흔들리다');
      expect(await c.correct(e), same(e));
    });
  });

  group('MeaningPunctuationCorrector', () {
    const c = MeaningPunctuationCorrector();

    test('a period between Korean words is a comma', () async {
      final e = await c.correct(entry(meaning: '싸다. 포장하다'));
      expect(e.meaning, '싸다, 포장하다');
      expect(e.issues.single.code, 'meaning:corrected');
      expect(e.issues.single.note, '싸다. 포장하다 → 싸다, 포장하다');
    });

    test('other periods stay', () async {
      for (final m in ['3.5배', '내리다.', '(교통) 정체']) {
        final e = entry(meaning: m);
        expect(await c.correct(e), same(e), reason: m);
      }
    });

    test('fixKoreanPeriods also fixes DAY titles', () {
      expect(fixKoreanPeriods('자연. 몸'), '자연, 몸');
    });
  });

  group('PosInferenceCorrector', () {
    const c = PosInferenceCorrector();

    test('kanji + u-row okurigana is a verb, kanji only a noun', () {
      expect(PosInferenceCorrector.inferPos('降りる'), PartOfSpeech.verb);
      expect(PosInferenceCorrector.inferPos('包む'), PartOfSpeech.verb);
      expect(PosInferenceCorrector.inferPos('切符'), PartOfSpeech.noun);
      expect(PosInferenceCorrector.inferPos('痛い'), isNull);
      expect(PosInferenceCorrector.inferPos('レシート'), isNull);
      expect(PosInferenceCorrector.inferPos('る'), isNull);
      expect(PosInferenceCorrector.inferPos(''), isNull);
    });

    test('fills a missing POS and marks it as a guess', () async {
      final e = await c.correct(entry(headword: '到着', pos: null));
      expect(e.pos, PartOfSpeech.noun);
      expect(e.issues.single.code, 'pos:inferred');
      expect(e.statusOf(EntryField.pos), FieldStatus.inferred);
      expect(e.needsReview, isFalse);
      expect(e.isFlagged, isTrue);
    });

    test('leaves a read POS and an unguessable headword alone', () async {
      final read = entry();
      expect(await c.correct(read), same(read));
      final kana = entry(headword: 'のんびり', pos: null);
      expect(await c.correct(kana), same(kana));
    });
  });

  group('CutMeaningFlagger', () {
    const c = CutMeaningFlagger();

    test('a meaning ending in a comma or middle dot is flagged', () async {
      for (final m in ['느긋하게,', '여행·', '느긋하게, ']) {
        final e = await c.correct(entry(meaning: m));
        expect(e.issues.single.code, 'meaning:suspect', reason: m);
        expect(e.statusOf(EntryField.meaning), FieldStatus.suspect);
        expect(e.needsReview, isTrue);
      }
    });

    test('a complete meaning is not flagged', () async {
      final e = entry(meaning: '느긋하게, 한가로이');
      expect(await c.correct(e), same(e));
    });
  });

  test('the standard chain has the new correctors before the flagger', () {
    expect(standardCorrectors(const EmptyDictionary()).map((c) => c.id), [
      'confusable-glyphs',
      'kana-okurigana',
      'reading-lookalikes',
      'badge-misreads',
      'meaning-punctuation',
      'pos-inference',
      'cut-meanings',
      'dictionary-candidates',
      'missing-fields',
    ]);
  });

  test('field status order: missing > suspect > corrected > inferred', () {
    final e = entry().copyWith(
      issues: const [
        EntryIssue.inferred(EntryField.pos),
        EntryIssue.corrected(EntryField.pos),
        EntryIssue.suspect(EntryField.meaning),
        EntryIssue.missing(EntryField.meaning),
      ],
    );
    expect(e.statusOf(EntryField.pos), FieldStatus.corrected);
    expect(e.statusOf(EntryField.meaning), FieldStatus.needsReview);
    expect(e.statusOf(EntryField.headword), FieldStatus.ok);
  });
}
