// E1, E2, E3: a な-adjective saved as a word list prints it (`X だ`, `X な`,
// reading `…だ`) keeps its headword, and is looked up without the ending:
// the card's dictionary example is the one of `X`'s entry. A word printed
// with no ending, or one the dictionary has with its ending, is looked up as
// before. Made-up entries and sentences only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

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

final class _Lexicon implements Lexicon {
  _Lexicon(List<LexiconWord> words) : _inner = InMemoryLexicon(words);

  final InMemoryLexicon _inner;
  final asked = <List<String>>[];

  @override
  Future<Map<String, List<LexiconEntry>>> lookup(Iterable<String> forms) {
    asked.add(forms.toList());
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
  pos: PartOfSpeech.naAdjective,
  example: example,
);

StoredExample _row(int entry, String ja, {String reading = '', String? ko}) =>
    StoredExample(
      entryId: entry,
      reading: reading,
      sentenceId: entry,
      ja: ja,
      ko: ko,
    );

void main() {
  group('E1 the word without its printed ending', () {
    /// [withoutPrintedEnding] as a list (headword first), or null.
    List<String>? bare(String headword, List<String> readings) =>
        switch (withoutPrintedEnding(headword, readings)) {
          null => null,
          final b => [b.headword, ...b.readings],
        };

    test('だ and な after kanji go, from the reading too', () {
      expect(bare('雪森だ', ['ゆきもりだ']), ['雪森', 'ゆきもり']);
      expect(bare('雪森な', ['ゆきもりな', 'せつしんな']), ['雪森', 'ゆきもり', 'せつしん']);
    });

    test('a reading printed without the ending stays as it is', () {
      expect(bare('雪森だ', ['ゆきもり']), ['雪森', 'ゆきもり']);
      expect(bare('雪森だ', const []), ['雪森']);
    });

    test('nothing to drop: no ending, no kanji, the ending alone', () {
      expect(bare('雪森', ['ゆきもり']), isNull);
      expect(bare('ゆきだ', ['ゆきだ']), isNull);
      expect(bare('だ', ['だ']), isNull);
      expect(bare('雪森に', ['ゆきもりに']), isNull);
    });
  });

  // 雪森 (な-adjective), 霧森な (an entry written with its な).
  final words = const [
    LexiconWord(
      id: 9310001,
      kanji: ['雪森'],
      readings: ['ゆきもり'],
      pos: ['adj-na'],
      priority: 4,
    ),
    LexiconWord(id: 9310002, kanji: ['霧森な'], readings: ['きりもりな']),
    LexiconWord(id: 9310003, kanji: ['霧森'], readings: ['きりもり']),
  ];
  final rows = [
    _row(9310001, '雪森な町です。', reading: 'ゆきもり', ko: '눈숲한 마을입니다.'),
    _row(9310002, '霧森な朝。', ko: '안개숲한 아침.'),
    _row(9310003, '霧森の話。', ko: '안개숲 이야기.'),
  ];

  group('E2 a card example through the word without its ending', () {
    test('`X だ` / `xだ` finds the sentence of X\'s entry', () async {
      for (final word in [
        _word('雪森だ', readings: ['ゆきもりだ']),
        _word('雪森な', readings: ['ゆきもりな']),
        _word('雪森だ', readings: ['ゆきもり']),
      ]) {
        final got = await cardExampleOf(
          word,
          lexicon: _Lexicon(words),
          examples: _Examples(rows),
        );
        expect(
          got,
          const CardExample(
            ja: '雪森な町です。',
            ko: '눈숲한 마을입니다.',
            origin: ExampleOrigin.tatoeba,
          ),
          reason: '${word.headword} ${word.readings}',
        );
      }
    });

    test('a page example still comes first, nothing looked up', () async {
      final lexicon = _Lexicon(words);
      final examples = _Examples(rows);
      final got = await cardExampleOf(
        _word(
          '雪森だ',
          readings: ['ゆきもりだ'],
          example: const Example(ja: '雪森だね。', ko: '눈숲하네.'),
        ),
        lexicon: lexicon,
        examples: examples,
      );
      expect(got?.origin, ExampleOrigin.page);
      expect(got?.ja, '雪森だね。');
      expect(lexicon.asked, isEmpty);
      expect(examples.calls, isEmpty);
    });
  });

  group('E3 as before', () {
    test('a word printed with no ending asks for its headword only', () async {
      final lexicon = _Lexicon(words);
      final got = await cardExampleOf(
        _word('雪森', readings: ['ゆきもり']),
        lexicon: lexicon,
        examples: _Examples(rows),
      );
      expect(got?.ja, '雪森な町です。');
      expect(lexicon.asked, [
        ['雪森'],
      ]);
    });

    test('an entry written with its ending is used as such', () async {
      final got = await cardExampleOf(
        _word('霧森な', readings: ['きりもりな']),
        lexicon: _Lexicon(words),
        examples: _Examples(rows),
      );
      expect(got?.ja, '霧森な朝。');
    });

    test('nothing in the dictionary either way: no example', () async {
      final got = await cardExampleOf(
        _word('雲森だ', readings: ['くももりだ']),
        lexicon: _Lexicon(words),
        examples: _Examples(rows),
      );
      expect(got, isNull);
    });
  });
}
