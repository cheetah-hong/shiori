import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

CapturedEntry entry(
  String headword, {
  List<String> readings = const ['いち'],
  PartOfSpeech? pos = PartOfSpeech.noun,
  String meaning = '뜻',
}) => CapturedEntry(
  no: '0001',
  headword: headword,
  readings: readings,
  pos: pos,
  meaning: meaning,
);

final class _FakeDictionary implements Dictionary {
  const _FakeDictionary(this.byKana);

  final Map<String, List<String>> byKana;

  @override
  Future<List<DictionaryEntry>> byReading(
    String reading, {
    int limit = 5,
    PartOfSpeech? pos,
  }) async => [
    for (final h in (byKana[reading] ?? const <String>[]).take(limit))
      DictionaryEntry(headword: h, readings: [reading]),
  ];

  @override
  Future<List<DictionaryEntry>> byHeadword(
    String headword, {
    int limit = 5,
  }) async => const [];

  @override
  Future<PairStatus> checkPair(String headword, List<String> readings) async =>
      PairStatus.unavailable;

  @override
  Future<List<String>> fixHeadword(
    String ocrHeadword,
    String reading, {
    PartOfSpeech? pos,
    int limit = 3,
  }) async => const [];
}

void main() {
  group('ConfusableGlyphCorrector', () {
    const c = ConfusableGlyphCorrector();

    test('a lone dash with a reading is 一', () async {
      final out = await c.correct(entry('ー'));
      expect(out.headword, '一');
      expect(out.statusOf(EntryField.headword), FieldStatus.corrected);
      expect(out.issues.single.note, 'ー → 一');
    });

    test('a lone dash without a reading is left alone (a kana word)', () async {
      final out = await c.correct(entry('ー', readings: const []));
      expect(out.headword, 'ー');
      expect(out.issues, isEmpty);
    });

    test('plus is 十', () async {
      expect(
        (await c.correct(entry('+', readings: const ['じゅう']))).headword,
        '十',
      );
    });

    test('katakana look-alikes inside a kanji word become kanji', () async {
      expect(
        (await c.correct(entry('タ日', readings: const ['ゆうひ']))).headword,
        '夕日',
      );
    });

    test('a lone look-alike next to a kanji becomes kanji', () async {
      expect(
        (await c.correct(entry('協カ', readings: const ['きょうりょく']))).headword,
        '協力',
      );
    });

    test('katakana runs of two or more glyphs are words: left alone', () async {
      for (final (h, r) in [
        ('アメリカ人', 'あめりかじん'),
        ('ローマ字', 'ろーまじ'),
        ('カタカナ語', 'かたかなご'),
      ]) {
        final out = await c.correct(entry(h, readings: [r]));
        expect(out.headword, h, reason: h);
        expect(out.issues, isEmpty, reason: h);
      }
    });

    test('a katakana word without kanji is not touched', () async {
      final out = await c.correct(entry('カタカナ', readings: const []));
      expect(out.headword, 'カタカナ');
    });

    // Checkbox marks read as text after a headword (`□□` → `ロロ`): a run made
    // only of look-alikes is kept but marked so the learner looks at it.
    test(
      'a run of look-alikes after a kanji word is kept and suspect',
      () async {
        final out = await c.correct(entry('到着ロロ', readings: const ['とうちゃく']));
        expect(out.headword, '到着ロロ');
        expect(out.issues.map((i) => i.code), ['headword:suspect']);
        expect(out.issues.single.note, contains('ロロ'));
        expect(out.statusOf(EntryField.headword), FieldStatus.suspect);
        expect(out.needsReview, isTrue);
      },
    );

    test('a katakana word with a kanji is not suspect', () async {
      final out = await c.correct(entry('アメリカ人', readings: const ['あめりかじん']));
      expect(out.headword, 'アメリカ人');
      expect(out.issues, isEmpty);
    });

    test('a lone look-alike is fixed, not suspect', () async {
      final out = await c.correct(entry('タ日', readings: const ['ゆうひ']));
      expect(out.headword, '夕日');
      expect(out.issues.map((i) => i.code), ['headword:corrected']);
    });

    test('look-alikes without a kanji are left alone, unflagged', () async {
      final out = await c.correct(entry('ロロロ', readings: const []));
      expect(out.headword, 'ロロロ');
      expect(out.issues, isEmpty);
    });
  });

  group('KanaOkuriganaCorrector', () {
    const c = KanaOkuriganaCorrector();

    test('カム read for 力む becomes 力む', () async {
      final out = await c.correct(entry('カム', readings: const ['りきむ']));
      expect(out.headword, '力む');
      expect(out.issues.single.code, 'headword:corrected');
    });

    test('leaves real katakana words with a long vowel mark alone', () async {
      final out = await c.correct(entry('コーヒー', readings: const ['こーひー']));
      expect(out.headword, 'コーヒー');
    });

    test('needs a hiragana reading', () async {
      expect((await c.correct(entry('カム', readings: const []))).headword, 'カム');
      expect(
        (await c.correct(entry('カム', readings: const ['リキム']))).headword,
        'カム',
      );
    });

    test('no change means no issue', () async {
      final out = await c.correct(entry('光る', readings: const ['ひかる']));
      expect(out.issues, isEmpty);
    });
  });

  group('MissingFieldFlagger', () {
    const c = MissingFieldFlagger();

    test('flags every empty core cell', () async {
      final out = await c.correct(
        entry('', readings: const [], pos: null, meaning: ''),
      );
      expect(out.issues.map((i) => i.code), [
        'headword:missing',
        'meaning:missing',
        'pos:missing',
      ]);
      expect(out.needsReview, isTrue);
    });

    test('a kanji word needs a reading; a kana word does not', () async {
      expect(
        (await c.correct(entry('天気予報', readings: const []))).issues.single.code,
        'readings:missing',
      );
      expect(
        (await c.correct(entry('もう', readings: const []))).issues,
        isEmpty,
      );
    });
  });

  test('flagMissingFields flags a cell the learner cleared, once', () {
    final cleared = entry('川').edit(meaning: '');
    final flagged = flagMissingFields(cleared);
    expect(flagged.issues.map((i) => i.code), ['meaning:missing']);
    expect(flagMissingFields(flagged).issues.length, 1);
    expect(missingFieldsOf(entry('川')), isEmpty);
  });

  group('DictionaryCandidateCorrector', () {
    test('offers words for the reading when the headword is missing', () async {
      const c = DictionaryCandidateCorrector(
        _FakeDictionary({
          'ひ': ['日', '火', '日'],
        }),
      );
      final out = await c.correct(entry('', readings: const ['ひ']));
      expect(out.headwordCandidates, ['日', '火']);
      expect(out.headword, isEmpty, reason: 'the learner picks the candidate');
    });

    test(
      'does nothing with the empty dictionary or when a headword exists',
      () async {
        const empty = DictionaryCandidateCorrector(EmptyDictionary());
        expect(
          (await empty.correct(
            entry('', readings: const ['ひ']),
          )).headwordCandidates,
          isEmpty,
        );
        const c = DictionaryCandidateCorrector(
          _FakeDictionary({
            'ひ': ['日'],
          }),
        );
        expect(
          (await c.correct(
            entry('日', readings: const ['ひ']),
          )).headwordCandidates,
          isEmpty,
        );
      },
    );
  });

  test('EmptyDictionary knows no words', () async {
    const d = EmptyDictionary();
    expect(await d.byReading('ひ'), isEmpty);
    expect(await d.byHeadword('日'), isEmpty);
  });
}
