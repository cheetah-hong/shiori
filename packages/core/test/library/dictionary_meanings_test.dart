// M3: the one lookup the word sheet and the built-in decks share — the
// glossaries in turn, each over the word's spellings in turn (and each
// spelling without an optional prefix in brackets), the first spelling with
// a sense deciding — and the word sheet asking with the reading a saved word
// has, so a kanji word read more than one way is looked up as the word it
// is. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

final class _Glossary implements KoreanGlossary {
  _Glossary(this.senses, {this.source = GlossarySource.krdict});

  final Map<String, List<String>> senses;
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
      for (final (i, text) in (senses[headword] ?? const []).indexed)
        KoreanSense(words: text.split(', '), source: source, senseNo: i + 1),
    ].take(limit).toList();
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

void main() {
  group('dictionaryMeanings', () {
    test('the first glossary with a sense for any spelling answers', () async {
      final first = _Glossary({
        '試甲': ['갑', '첫째'],
      });
      final second = _Glossary({
        '試甲': ['다른 갑'],
        '試乙': ['을'],
      }, source: GlossarySource.wiktionary);

      expect(
        await dictionaryMeanings([first, second], ['試甲'], readings: ['しこう']),
        ['갑', '첫째'],
      );
      expect(
        await dictionaryMeanings([first, second], ['試乙'], readings: ['しおつ']),
        ['을'],
      );
    });

    test('a later glossary is asked only when the first has none for every '
        'spelling', () async {
      final first = _Glossary({
        '試丙二': ['병'],
      });
      final second = _Glossary({
        '試丙一': ['다른 병'],
      });

      expect(
        await dictionaryMeanings(
          [first, second],
          ['試丙一', '試丙二'],
          readings: ['しへい'],
        ),
        ['병'],
      );
    });

    test('the first spelling with a sense decides; later spellings are not '
        'mixed in', () async {
      final g = _Glossary({
        '試丁': ['정'],
        '試丁丁': ['정정', '또 정'],
      });

      expect(await dictionaryMeanings([g], ['試丁丁', '試丁'], readings: ['してい']), [
        '정정',
        '또 정',
      ]);
      expect(g.asked.map((a) => a.headword), ['試丁丁']);
    });

    test('a spelling with an optional prefix is also asked with and without '
        'it', () async {
      final g = _Glossary({
        'おみやげ': ['선물'],
        'みやげ': ['토산품', '선물'],
      });

      expect(await dictionaryMeanings([g], ['(お)みやげ'], readings: const []), [
        '선물',
        '토산품',
      ]);
    });

    test('each meaning once, at most the limit', () async {
      final g = _Glossary({
        '試戊': ['무', '다섯째', '무', '오', '戊', '여섯'],
      });

      expect(
        await dictionaryMeanings([g], ['試戊'], readings: const [], limit: 3),
        ['무', '다섯째', '오'],
      );
      expect(
        (await dictionaryMeanings([g], ['試戊'], readings: const [])).length,
        maxMeaningCandidates,
      );
    });

    test('the readings and class go to every ask', () async {
      final g = _Glossary({});

      await dictionaryMeanings(
        [g],
        ['試己', '試己己'],
        readings: ['しき'],
        pos: PartOfSpeech.verb,
      );

      expect([for (final a in g.asked) a.headword], ['試己', '試己己']);
      for (final a in g.asked) {
        expect(a.readings, ['しき']);
        expect(a.pos, PartOfSpeech.verb);
      }
    });

    test('nothing anywhere: no meanings', () async {
      expect(
        await dictionaryMeanings([_Glossary({})], ['試庚'], readings: const []),
        isEmpty,
      );
    });
  });

  group('wordFill with the saved word\'s reading', () {
    // 試頭 is read しあたま (common) and しとう.
    final lexicon = InMemoryLexicon(const [
      LexiconWord(
        id: 9400001,
        kanji: ['試頭'],
        readings: ['しあたま'],
        pos: ['n'],
        priority: lexiconCommonMask,
      ),
      LexiconWord(id: 9400002, kanji: ['試頭'], readings: ['しとう'], pos: ['adv']),
    ]);
    final glossary = _Glossary({});
    const byReading = _ReadingGlossary({
      ('試頭', 'しあたま'): ['머리'],
      ('試頭', 'しとう'): ['마리'],
    });

    test('without a reading: the common entry, as before', () async {
      final fill = await wordFill('試頭', lexicon: lexicon, glossary: byReading);

      expect(fill.readings, ['しあたま']);
      expect(fill.meanings.first, '머리');
    });

    test('with the saved reading: the entry read so', () async {
      final fill = await wordFill(
        '試頭',
        lexicon: lexicon,
        glossary: byReading,
        readings: ['しとう'],
      );

      expect(fill.readings, ['しとう']);
      expect(fill.pos, PartOfSpeech.adverb);
      expect(fill.meanings.first, '마리');
    });

    test('a reading typed in katakana is the same reading', () async {
      final fill = await wordFill(
        '試頭',
        lexicon: lexicon,
        glossary: byReading,
        readings: ['シトウ'],
      );

      expect(fill.readings, ['しとう']);
    });

    test('a reading no entry has: as without one', () async {
      final fill = await wordFill(
        '試頭',
        lexicon: lexicon,
        glossary: byReading,
        readings: ['しず'],
      );

      expect(fill.readings, ['しあたま']);
      expect(fill.meanings.first, '머리');
    });

    test('a kana headword ignores readings', () async {
      final kana = await wordFill(
        'しとう',
        lexicon: lexicon,
        glossary: glossary,
        readings: ['しとう'],
      );
      final bare = await wordFill('しとう', lexicon: lexicon, glossary: glossary);

      expect(kana, bare);
    });
  });
}

/// Senses by spelling and reading.
final class _ReadingGlossary implements KoreanGlossary {
  const _ReadingGlossary(this.senses);

  final Map<(String, String), List<String>> senses;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => [
    for (final r in readings)
      for (final text in senses[(headword, r)] ?? const <String>[])
        KoreanSense(words: [text], source: GlossarySource.krdict),
  ].take(limit).toList();

  @override
  List<GlossarySourceInfo> get sources => const [];
}
