// X3: the example a study card shows: the page's own example first, else a
// Tatoeba sentence found through the dictionary entry of the word (made-up
// entries and sentences only).
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// Counts its calls; answers from [rows] by entry id.
final class _Examples implements ExampleSentences {
  _Examples(this.rows);

  final List<StoredExample> rows;
  final calls = <List<int>>[];

  @override
  Future<List<StoredExample>> lookup(Iterable<int> entryIds) async {
    final ids = entryIds.toList();
    calls.add(ids);
    return [
      for (final r in rows)
        if (ids.contains(r.entryId)) r,
    ];
  }
}

/// Counts its calls.
final class _Lexicon implements Lexicon {
  _Lexicon(List<LexiconWord> words) : _inner = InMemoryLexicon(words);

  final InMemoryLexicon _inner;
  var calls = 0;

  @override
  Future<Map<String, List<LexiconEntry>>> lookup(Iterable<String> forms) {
    calls++;
    return _inner.lookup(forms);
  }
}

Word _word(
  String headword, {
  List<String> readings = const [],
  Example? example,
}) => Word(
  id: 'w:$headword',
  headword: headword,
  readings: readings,
  meaning: '뜻',
  createdAt: DateTime.utc(2026, 11, 12),
  example: example,
);

StoredExample _row(
  int entry,
  String ja, {
  String reading = '',
  String? ko,
  String? en,
  String? surface,
  int sentence = 1,
}) => StoredExample(
  entryId: entry,
  reading: reading,
  sentenceId: sentence,
  ja: ja,
  ko: ko,
  en: en,
  surface: surface,
);

void main() {
  // 雪森 (ゆきもり / せつしん: two entries), 汚森す (a verb), 七森 (two readings
  // in one entry), ぽる (kana; a usually-kana entry and a rare kana-only one).
  final lexicon = _Lexicon(const [
    LexiconWord(id: 9300001, kanji: ['雪森'], readings: ['ゆきもり'], priority: 4),
    LexiconWord(id: 9300002, kanji: ['雪森'], readings: ['せつしん']),
    LexiconWord(id: 9300003, kanji: ['汚森す'], readings: ['よごもりす'], pos: ['v5s']),
    LexiconWord(id: 9300004, kanji: ['七森'], readings: ['しちもり', 'ななもり']),
    LexiconWord(id: 9300005, readings: ['ぽる']),
    LexiconWord(
      id: 9300006,
      kanji: ['穂留'],
      readings: ['ぽる'],
      priority: 4,
      usuallyKana: true,
    ),
    LexiconWord(id: 9300007, kanji: ['珈森'], readings: ['コーモリ'], priority: 4),
  ]);

  setUp(() => lexicon.calls = 0);

  test('the page example comes first and nothing is looked up', () async {
    final examples = _Examples([_row(9300001, '雪森へ行きます。', ko: '눈숲에 갑니다.')]);
    final word = _word(
      '雪森',
      readings: ['ゆきもり'],
      example: const Example(ja: '雪森が白い。', ko: '눈숲이 하얗다.'),
    );

    final got = await cardExampleOf(word, lexicon: lexicon, examples: examples);

    expect(
      got,
      const CardExample(
        ja: '雪森が白い。',
        ko: '눈숲이 하얗다.',
        origin: ExampleOrigin.page,
      ),
    );
    expect(got!.isFilled, isFalse);
    expect(examples.calls, isEmpty);
    expect(lexicon.calls, 0);
  });

  test('a page example without a translation has none', () async {
    final word = _word(
      '雪森',
      example: const Example(ja: '雪森が白い。', ko: ''),
    );
    final got = await cardExampleOf(
      word,
      lexicon: lexicon,
      examples: _Examples(const []),
    );
    expect(got?.ko, isNull);
    expect(got?.en, isNull);
  });

  test('without a page example: the sentence of the word\'s entry', () async {
    final examples = _Examples([
      _row(9300002, '雪森の話。', ko: '설심 이야기.'),
      _row(9300001, '雪森へ行きます。', ko: '눈숲에 갑니다.', sentence: 42),
    ]);

    final got = await cardExampleOf(
      _word('雪森', readings: ['ゆきもり']),
      lexicon: lexicon,
      examples: examples,
    );

    expect(
      got,
      const CardExample(
        ja: '雪森へ行きます。',
        ko: '눈숲에 갑니다.',
        origin: ExampleOrigin.tatoeba,
      ),
    );
    expect(got!.isFilled, isTrue);
    // The kanji form is narrowed by the card's reading.
    expect(examples.calls, [
      [9300001],
    ]);
  });

  test('English when the sentence has no Korean', () async {
    final got = await cardExampleOf(
      _word('雪森', readings: ['ゆきもり']),
      lexicon: lexicon,
      examples: _Examples([
        _row(9300001, '雪森へ行きます。', en: 'I go to the snow wood.'),
      ]),
    );
    expect(got?.ko, isNull);
    expect(got?.en, 'I go to the snow wood.');
  });

  test('a conjugated use is found through the dictionary form', () async {
    final got = await cardExampleOf(
      _word('汚森す', readings: ['よごもりす']),
      lexicon: lexicon,
      examples: _Examples([
        _row(9300003, '服を汚森してしまった。', surface: '汚森して'),
      ]),
    );
    expect(got?.ja, '服を汚森してしまった。');
    expect(got?.surface, '汚森して');
  });

  test("a row of the card's reading before a row of any reading", () async {
    final examples = _Examples([
      _row(9300004, '七森時に起きます。', reading: 'しちもり'),
      _row(9300004, '七森回聞きました。', reading: 'ななもり'),
      _row(9300004, '七森が好きです。'),
    ]);
    Future<String?> jaFor(List<String> readings) async => (await cardExampleOf(
      _word('七森', readings: readings),
      lexicon: lexicon,
      examples: examples,
    ))?.ja;

    expect(await jaFor(['ななもり']), '七森回聞きました。');
    expect(await jaFor(['しちもり']), '七森時に起きます。');
    expect(await jaFor([]), '七森が好きです。');
  });

  test('a row of another reading only: no example', () async {
    final got = await cardExampleOf(
      _word('七森', readings: ['ななもり']),
      lexicon: lexicon,
      examples: _Examples([
        _row(9300004, '七森時に起きます。', reading: 'しちもり'),
      ]),
    );
    expect(got, isNull);
  });

  test('a katakana reading matches its hiragana row', () async {
    final got = await cardExampleOf(
      _word('珈森', readings: ['コーモリ']),
      lexicon: lexicon,
      examples: _Examples([
        _row(9300007, '珈森を飲みます。', reading: 'こーもり'),
      ]),
    );
    expect(got?.ja, '珈森を飲みます。');
  });

  test('a kana word stands for the entry usually written in kana', () async {
    final examples = _Examples([
      _row(9300005, 'ぽるがある。'),
      _row(9300006, 'ぽるを見ました。'),
    ]);
    final got = await cardExampleOf(
      _word('ぽる'),
      lexicon: lexicon,
      examples: examples,
    );
    expect(got?.ja, 'ぽるを見ました。');
    expect(examples.calls, [
      [9300006],
    ]);
  });

  test('a word the dictionary does not have: no example', () async {
    final examples = _Examples([_row(9300001, '雪森へ行きます。')]);
    final got = await cardExampleOf(
      _word('月道'),
      lexicon: lexicon,
      examples: examples,
    );
    expect(got, isNull);
    expect(examples.calls, isEmpty);
  });

  test('no sentence for the entry: no example', () async {
    final got = await cardExampleOf(
      _word('雪森', readings: ['ゆきもり']),
      lexicon: lexicon,
      examples: const EmptyExampleSentences(),
    );
    expect(got, isNull);
  });

  test('with two entries left, the first with a sentence', () async {
    final got = await cardExampleOf(
      _word('雪森'),
      lexicon: lexicon,
      examples: _Examples([_row(9300002, '雪森の話です。')]),
    );
    expect(got?.ja, '雪森の話です。');
  });
}
