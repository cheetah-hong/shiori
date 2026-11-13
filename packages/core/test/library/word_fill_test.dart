// E3·E4: what the dictionaries fill for a headword the learner typed (단어
// 추가, 사전에서 다시 찾기), and how it merges with what is on the form: an
// empty field takes the dictionary's value, a field with a value keeps it
// and only gets a suggestion — a meaning the learner wrote is never
// replaced. A headword in kana offers kanji spellings. Examples are not
// stored: the card looks them up by the changed headword (だ rule). Made-up
// words and dictionary entries.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// Senses by headword; every ask is recorded.
final class _Glossary implements KoreanGlossary {
  _Glossary(this.byHeadword, {this.source = GlossarySource.krdict});

  final Map<String, List<String>> byHeadword;
  final GlossarySource source;
  final List<({String headword, List<String> readings, PartOfSpeech? pos})>
  asked = [];

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    asked.add((headword: headword, readings: readings, pos: pos));
    return [
      for (final (i, text) in (byHeadword[headword] ?? const []).indexed)
        KoreanSense(words: [text], source: source, senseNo: i + 1),
    ].take(limit).toList();
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

final class _Examples implements ExampleSentences {
  const _Examples(this.byEntry);

  final Map<int, String> byEntry;

  @override
  Future<List<StoredExample>> lookup(Iterable<int> entryIds) async => [
    for (final id in entryIds)
      if (byEntry[id] case final String ja)
        StoredExample(entryId: id, reading: '', sentenceId: id, ja: ja),
  ];
}

final _lexicon = InMemoryLexicon(const [
  LexiconWord(id: 9100001, kanji: ['試語甲'], readings: ['しごこう'], pos: ['n']),
  LexiconWord(id: 9100002, kanji: ['試語乙'], readings: ['しごおつ'], pos: ['v5r']),
  LexiconWord(id: 9100003, kanji: ['試便'], readings: ['しべん'], pos: ['adj-na']),
  // Two words read しごか: the common one first.
  LexiconWord(id: 9100011, kanji: ['支語華'], readings: ['しごか'], pos: ['n']),
  LexiconWord(
    id: 9100010,
    kanji: ['試語花'],
    readings: ['しごか'],
    pos: ['n'],
    priority: lexiconCommonMask,
  ),
]);

final _glossary = _Glossary({
  '試語甲': ['시험 낱말', '시험어'],
  '試便': ['편리함'],
  '試語花': ['시험 꽃'],
  '支語華': ['지어 화'],
});

void main() {
  group('E4 wordFill', () {
    test('a headword with kanji: reading, class and meanings', () async {
      final glossary = _Glossary(_glossary.byHeadword);
      final fill = await wordFill('試語甲', lexicon: _lexicon, glossary: glossary);
      expect(fill.found, isTrue);
      expect(fill.readings, ['しごこう']);
      expect(fill.pos, PartOfSpeech.noun);
      expect(fill.meanings, ['시험 낱말', '시험어']);
      expect(fill.kanjiChoices, isEmpty);
      final asked = glossary.asked.first;
      expect(asked.headword, '試語甲');
      expect(asked.readings, ['しごこう']);
      expect(asked.pos, PartOfSpeech.noun);
    });

    test('a な-adjective printed with だ is looked up bare', () async {
      final fill = await wordFill(
        '試便だ',
        lexicon: _lexicon,
        glossary: _glossary,
      );
      expect(fill.found, isTrue);
      expect(fill.readings, ['しべん']);
      expect(fill.pos, PartOfSpeech.naAdjective);
      expect(fill.meanings, ['편리함']);
    });

    test('a meaning the glossary lacks comes from the fallback', () async {
      final fill = await wordFill(
        '試語乙',
        lexicon: _lexicon,
        glossary: _glossary,
        fallback: _Glossary({
          '試語乙': ['시험 동사'],
        }, source: GlossarySource.wiktionary),
      );
      expect(fill.pos, PartOfSpeech.verb);
      expect(fill.meanings, ['시험 동사']);
    });

    test('a word no dictionary has fills nothing', () async {
      final fill = await wordFill(
        '試語戊',
        lexicon: _lexicon,
        glossary: _glossary,
      );
      expect(fill, WordFill.none);
    });

    test('a headword in kana offers kanji spellings, common first', () async {
      final fill = await wordFill(
        'しごか',
        lexicon: _lexicon,
        glossary: _glossary,
      );
      expect(fill.found, isTrue);
      expect(fill.readings, isEmpty, reason: 'a word in kana keeps none');
      expect(fill.kanjiChoices, const [
        KanjiChoice(
          headword: '試語花',
          reading: 'しごか',
          pos: PartOfSpeech.noun,
          meaning: '시험 꽃',
        ),
        KanjiChoice(
          headword: '支語華',
          reading: 'しごか',
          pos: PartOfSpeech.noun,
          meaning: '지어 화',
        ),
      ]);
      expect(fill.meanings, [
        '시험 꽃',
      ], reason: 'kept in kana, it means the likeliest word');
    });

    test('katakana typed for a kana spelling finds the same words', () async {
      final fill = await wordFill(
        'シゴカ',
        lexicon: _lexicon,
        glossary: _glossary,
      );
      expect(fill.kanjiChoices.map((c) => c.headword), ['試語花', '支語華']);
    });

    test('a blank headword asks nothing', () async {
      final glossary = _Glossary(_glossary.byHeadword);
      expect(
        await wordFill('  ', lexicon: _lexicon, glossary: glossary),
        WordFill.none,
      );
      expect(glossary.asked, isEmpty);
    });
  });

  group('E3 mergeFill never replaces what is written', () {
    const fill = WordFill(
      found: true,
      readings: ['しごこう'],
      pos: PartOfSpeech.noun,
      meanings: ['시험 낱말', '시험어'],
    );

    test('empty fields take the dictionary\'s values', () {
      final merged = mergeFill(
        const WordEdit(headword: '試語甲', meaning: ''),
        fill,
      );
      expect(
        merged.edit,
        const WordEdit(
          headword: '試語甲',
          readings: ['しごこう'],
          pos: PartOfSpeech.noun,
          meaning: '시험 낱말',
        ),
      );
      expect(merged.filled, {
        EntryField.readings,
        EntryField.pos,
        EntryField.meaning,
      });
      expect(merged.meaningSuggestions, ['시험어']);
      expect(merged.readingSuggestion, isNull);
      expect(merged.posSuggestion, isNull);
    });

    test('a written meaning stays; the dictionary\'s are suggestions', () {
      final merged = mergeFill(
        const WordEdit(
          headword: '試語甲',
          readings: ['しごこう'],
          pos: PartOfSpeech.noun,
          meaning: '내가 쓴 뜻',
        ),
        fill,
      );
      expect(merged.edit.meaning, '내가 쓴 뜻');
      expect(merged.filled, isEmpty);
      expect(merged.meaningSuggestions, ['시험 낱말', '시험어']);
    });

    test('a meaning equal to the dictionary\'s is not suggested again', () {
      final merged = mergeFill(
        const WordEdit(headword: '試語甲', meaning: ' 시험 낱말 '),
        fill,
      );
      expect(merged.meaningSuggestions, ['시험어']);
    });

    test('other readings and class are suggested, not written', () {
      final merged = mergeFill(
        const WordEdit(
          headword: '試語甲',
          readings: ['しごこ'],
          pos: PartOfSpeech.verb,
          meaning: '뜻',
        ),
        fill,
      );
      expect(merged.edit.readings, ['しごこ']);
      expect(merged.edit.pos, PartOfSpeech.verb);
      expect(merged.readingSuggestion, ['しごこう']);
      expect(merged.posSuggestion, PartOfSpeech.noun);
    });

    test('nothing found changes nothing', () {
      const current = WordEdit(headword: '試語戊', meaning: '');
      final merged = mergeFill(current, WordFill.none);
      expect(merged.edit, current);
      expect(merged.filled, isEmpty);
      expect(merged.meaningSuggestions, isEmpty);
    });
  });

  group('E3 the card looks examples up by the changed headword', () {
    final examples = const _Examples({9100001: '試語甲の例文。', 9100003: '試便な例文。'});

    Word word(String head, List<String> readings) => Word(
      id: 'w1',
      headword: head,
      readings: readings,
      meaning: '뜻',
      createdAt: DateTime(2026, 11, 14),
    );

    test('before and after the change, だ rule kept', () async {
      final before = await cardExampleOf(
        word('試語甲', ['しごこう']),
        lexicon: _lexicon,
        examples: examples,
      );
      final after = await cardExampleOf(
        word('試便だ', ['しべんだ']),
        lexicon: _lexicon,
        examples: examples,
      );
      expect(before?.ja, '試語甲の例文。');
      expect(after?.ja, '試便な例文。');
    });
  });
}
