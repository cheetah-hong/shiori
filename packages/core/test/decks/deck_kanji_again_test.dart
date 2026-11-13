// F3: a word an easier deck shows in kana comes back in a harder deck in
// kanji (the deck file's rule, tools/decks/build_decks.py). Its spelling is
// another word key, so by the library's rule it is another word: adding
// both decks, in either order, makes one word per key, never two words of
// one key, and the kanji word shares the record of a word of that spelling
// the library has already. Made-up words, a fixed clock.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// The first sense by headword.
final class _Glossary implements KoreanGlossary {
  const _Glossary(this.byHeadword);

  final Map<String, String> byHeadword;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => [
    if (byHeadword[headword] case final String meaning)
      KoreanSense(words: [meaning], source: GlossarySource.krdict, senseNo: 1),
  ];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

const _glossary = _Glossary({'あまぐも': '비구름', '雨雲': '비구름', 'こかげ': '나무 그늘'});

/// The easier deck shows the word in kana, the harder one in kanji.
const _easy = BuiltinDeck(
  id: 'jlpt-n5',
  name: 'JLPT N5 대비',
  level: 'N5',
  words: [
    DeckWord(headword: 'あまぐも', reading: 'あまぐも', entryId: 9100001),
    DeckWord(headword: 'こかげ', reading: 'こかげ', entryId: 9100002),
  ],
);

const _hard = BuiltinDeck(
  id: 'jlpt-n1',
  name: 'JLPT N1 대비',
  level: 'N1',
  words: [DeckWord(headword: '雨雲', reading: 'あまぐも', entryId: 9100001)],
);

void main() {
  final now = DateTime(2026, 11, 14, 9);
  late InMemoryLibraryRepository library;
  late InMemoryReviewRepository reviews;
  late LibraryService service;

  Future<AddResult> add(BuiltinDeck deck) async => service.addDeck(
    await deckDraft(deck, lexicon: const EmptyLexicon(), glossary: _glossary),
  );

  setUp(() {
    library = InMemoryLibraryRepository();
    reviews = InMemoryReviewRepository();
    service = LibraryService(library: library, clock: FixedClock(now));
  });

  /// Every word of the library by its key; fails on a key twice.
  Future<Map<String, Word>> byKey() async {
    final out = <String, Word>{};
    for (final w in await library.words()) {
      expect(out.containsKey(wordKey(w.headword)), isFalse, reason: w.headword);
      out[wordKey(w.headword)] = w;
    }
    return out;
  }

  test('the harder deck holds the kanji word, its reading kept', () async {
    final result = await add(_hard);

    final words = await library.words(playlistId: result.playlist.id);
    expect([for (final w in words) w.headword], ['雨雲']);
    expect(words.single.readings, ['あまぐも']);
    expect(words.single.meaning, '비구름');
  });

  test('easier deck first: one word per spelling, none twice', () async {
    await add(_easy);
    final hard = await add(_hard);

    expect(hard.added, 1);
    expect(hard.linked, 0);
    final keys = await byKey();
    expect(keys.keys, unorderedEquals(['あまぐも', 'こかげ', '雨雲']));
    expect(keys['あまぐも']!.readings, isEmpty);
    expect(keys['雨雲']!.readings, ['あまぐも']);
  });

  test('harder deck first: the same words', () async {
    await add(_hard);
    final easy = await add(_easy);

    expect(easy.added, 2);
    expect(easy.linked, 0);
    expect((await byKey()).keys, unorderedEquals(['あまぐも', 'こかげ', '雨雲']));
  });

  test('each deck again adds nothing', () async {
    await add(_easy);
    await add(_hard);

    final easy = await add(_easy);
    final hard = await add(_hard);

    expect([easy.added, easy.linked, easy.alreadyIn], [0, 0, 2]);
    expect([hard.added, hard.linked, hard.alreadyIn], [0, 0, 1]);
    expect(await library.words(), hasLength(3));
  });

  test(
    'the kanji word links to the library word of its spelling, record and all',
    () async {
      final mine = Word(
        id: 'w-mine',
        headword: '雨雲',
        readings: const ['あまぐも'],
        meaning: '내가 적은 뜻',
        createdAt: now.subtract(const Duration(days: 5)),
      );
      await library.insertWords([mine]);
      final card = ReviewCard(
        wordId: 'w-mine',
        level: 2,
        dueAt: now.add(const Duration(days: 1)),
        lastReviewedAt: now.subtract(const Duration(days: 1)),
        reviewCount: 3,
      );
      await reviews.saveCard(card);

      await add(_easy);
      final hard = await add(_hard);

      expect(hard.added, 0);
      expect(hard.linked, 1);
      final words = await library.words(playlistId: hard.playlist.id);
      expect(words.single, mine);
      expect(await reviews.card('w-mine'), card);
      // The kana word of the easier deck is its own word, with no record.
      final kana = (await byKey())['あまぐも']!;
      expect(kana.id, isNot('w-mine'));
      expect(await reviews.card(kana.id), isNull);
    },
  );
}
