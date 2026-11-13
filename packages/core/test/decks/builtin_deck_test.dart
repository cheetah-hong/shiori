// B3·B4: built-in decks. The asset is read and checked; a deck becomes a
// draft whose meanings and classes come from the app's dictionaries (the
// way the word extractor fills a dictionary word), words without a meaning
// are left out and counted; adding a deck makes an ordinary playlist under
// the library's rules (one word per headword, records shared, hidden words
// stay hidden, adding again adds only what is missing); the words then study
// like any other. Made-up words and dictionary entries, a fixed clock.
import 'dart:convert';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// Senses by headword; every ask is recorded.
final class _Glossary implements KoreanGlossary {
  _Glossary(this.byHeadword, {this.source = GlossarySource.krdict});

  final Map<String, List<List<String>>> byHeadword;
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
      for (final (i, words) in (byHeadword[headword] ?? const []).indexed)
        KoreanSense(words: words, source: source, senseNo: i + 1),
    ].take(limit).toList();
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

/// Sentences by entry id.
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

const _sources = [
  {
    'name': '단어 목록',
    'author': '지어낸 저자',
    'license': 'CC BY 4.0',
    'licenseUrl': 'https://example.com/license',
    'url': 'https://example.com/list',
  },
];

Map<String, Object?> _asset({
  List<Map<String, Object?>>? decks,
  Object? format = 'shiori-decks',
  Object? version = 1,
}) => {
  'format': format,
  'version': version,
  'edition': '2026-11-13',
  'sources': _sources,
  'decks':
      decks ??
      [
        {
          'id': 'jlpt-n5',
          'name': 'JLPT N5 대비',
          'level': 'N5',
          'words': [
            {'h': '雨傘', 'r': 'あまがさ', 'e': 9000001},
            {'h': 'ぽかぽか', 'r': 'ぽかぽか', 'e': 9000002},
            {'h': 'カメラ', 'r': 'カメラ', 'e': 9000003},
            {'h': 'ひなた', 'r': 'ひなた', 'e': 9000004, 'l': '日向'},
            {'h': '夕凪', 'r': 'ゆうなぎ', 'e': 9000005, 'm': '저녁뜸'},
          ],
        },
      ],
};

BuiltinDeckSet _parse(Map<String, Object?> asset) =>
    parseBuiltinDecks(jsonEncode(asset));

/// A deck of the given words: (headword, reading, entry, lookup, meaning).
BuiltinDeck _deck(
  List<(String, String, int, String?, String?)> words, {
  String name = 'JLPT N5 대비',
}) => BuiltinDeck(
  id: 'jlpt-n5',
  name: name,
  level: 'N5',
  words: [
    for (final (h, r, e, l, m) in words)
      DeckWord(headword: h, reading: r, entryId: e, lookupForm: l, meaning: m),
  ],
);

final _lexicon = InMemoryLexicon([
  // Two entries spelled 雨傘: the deck names the second.
  const LexiconWord(
    id: 9000101,
    kanji: ['雨傘'],
    readings: ['うさん'],
    pos: ['adv'],
  ),
  const LexiconWord(id: 9000001, kanji: ['雨傘'], readings: ['あまがさ'], pos: ['n']),
  const LexiconWord(id: 9000002, readings: ['ぽかぽか'], pos: ['adv']),
  const LexiconWord(id: 9000003, readings: ['カメラ'], pos: ['n']),
  const LexiconWord(
    id: 9000004,
    kanji: ['日向'],
    readings: ['ひなた'],
    pos: ['n'],
    usuallyKana: true,
  ),
  const LexiconWord(id: 9000005, kanji: ['夕凪'], readings: ['ゆうなぎ'], pos: ['n']),
  const LexiconWord(id: 9000006, kanji: ['小道'], readings: ['こみち'], pos: ['n']),
]);

void main() {
  group('parseBuiltinDecks', () {
    test('reads the decks, their words and the sources', () {
      final set = _parse(_asset());

      expect(set.edition, '2026-11-13');
      expect(set.sources.single.author, '지어낸 저자');
      expect(set.sources.single.license, 'CC BY 4.0');
      expect(set.sources.single.licenseUrl, 'https://example.com/license');
      expect(set.sources.single.url, 'https://example.com/list');
      final deck = set.decks.single;
      expect(deck.id, 'jlpt-n5');
      expect(deck.name, 'JLPT N5 대비');
      expect(deck.level, 'N5');
      expect(
        [for (final w in deck.words) w.headword],
        ['雨傘', 'ぽかぽか', 'カメラ', 'ひなた', '夕凪'],
      );
      final kasa = deck.words.first;
      expect(kasa.reading, 'あまがさ');
      expect(kasa.entryId, 9000001);
      expect(kasa.lookupForm, isNull);
      expect(kasa.meaning, isNull);
      expect(deck.words[3].lookupForm, '日向');
      expect(deck.words[4].meaning, '저녁뜸');
    });

    test('a word written in kana has no readings, a kanji word its one', () {
      final words = _parse(_asset()).decks.single.words;

      expect(words[0].readings, ['あまがさ']);
      expect(words[1].readings, isEmpty);
      expect(words[2].readings, isEmpty);
      expect(words[3].readings, isEmpty);
    });

    test('decks keep the order of the file', () {
      final set = _parse(
        _asset(
          decks: [
            for (final level in ['N5', 'N4', 'N3'])
              {
                'id': 'jlpt-${level.toLowerCase()}',
                'name': 'JLPT $level 대비',
                'level': level,
                'words': [
                  {'h': '小道', 'r': 'こみち', 'e': 9000006},
                ],
              },
          ],
        ),
      );

      expect([for (final d in set.decks) d.level], ['N5', 'N4', 'N3']);
    });

    final broken = <String, Object?>{
      'not JSON': '{',
      'not an object': '[]',
      'another format': _asset(format: 'shiori-backup'),
      'a newer version': _asset(version: 2),
      'a version that is no integer': _asset(version: '1'),
      'no decks': _asset(decks: []),
      'a deck without a name': _asset(
        decks: [
          {
            'id': 'x',
            'level': 'N5',
            'words': [
              {'h': '小道', 'r': 'こみち', 'e': 9000006},
            ],
          },
        ],
      ),
      'two decks with one id': _asset(
        decks: [
          for (var i = 0; i < 2; i++)
            {
              'id': 'x',
              'name': '목록 $i',
              'level': 'N5',
              'words': [
                {'h': '小道', 'r': 'こみち', 'e': 9000006},
              ],
            },
        ],
      ),
      'a deck without words': _asset(
        decks: [
          {'id': 'x', 'name': '목록', 'level': 'N5', 'words': <Object>[]},
        ],
      ),
      'a word without an entry': _asset(
        decks: [
          {
            'id': 'x',
            'name': '목록',
            'level': 'N5',
            'words': [
              {'h': '小道', 'r': 'こみち'},
            ],
          },
        ],
      ),
      'an entry that is no integer': _asset(
        decks: [
          {
            'id': 'x',
            'name': '목록',
            'level': 'N5',
            'words': [
              {'h': '小道', 'r': 'こみち', 'e': '9000006'},
            ],
          },
        ],
      ),
      'a blank headword': _asset(
        decks: [
          {
            'id': 'x',
            'name': '목록',
            'level': 'N5',
            'words': [
              {'h': ' ', 'r': 'こみち', 'e': 9000006},
            ],
          },
        ],
      ),
      'a blank reading': _asset(
        decks: [
          {
            'id': 'x',
            'name': '목록',
            'level': 'N5',
            'words': [
              {'h': '小道', 'r': '', 'e': 9000006},
            ],
          },
        ],
      ),
      'one word twice in a deck': _asset(
        decks: [
          {
            'id': 'x',
            'name': '목록',
            'level': 'N5',
            'words': [
              {'h': '小道', 'r': 'こみち', 'e': 9000006},
              {'h': '小道 ', 'r': 'しょうどう', 'e': 9000007},
            ],
          },
        ],
      ),
      'an unknown key on a word': _asset(
        decks: [
          {
            'id': 'x',
            'name': '목록',
            'level': 'N5',
            'words': [
              {'h': '小道', 'r': 'こみち', 'e': 9000006, 'x': 1},
            ],
          },
        ],
      ),
    };
    for (final MapEntry(key: name, value: asset) in broken.entries) {
      test('refuses $name', () {
        final text = asset is String ? asset : jsonEncode(asset);
        expect(() => parseBuiltinDecks(text), throwsFormatException);
      });
    }
  });

  group('deckDraft', () {
    test(
      'fills meaning and class from the dictionaries, in deck order',
      () async {
        final glossary = _Glossary({
          '雨傘': [
            ['우산'],
            ['비옷'],
          ],
          'ぽかぽか': [
            ['따끈따끈'],
          ],
          'カメラ': [
            ['카메라'],
          ],
          '日向': [
            ['양지', '양달'],
          ],
          '夕凪': [
            ['저녁뜸'],
          ],
        });
        final deck = _parse(_asset()).decks.single;

        final result = await deckDraft(
          deck,
          lexicon: _lexicon,
          glossary: glossary,
        );

        final entries = result.draft.entries;
        expect(
          [for (final e in entries) e.headword],
          ['雨傘', 'ぽかぽか', 'カメラ', 'ひなた', '夕凪'],
        );
        expect(
          [for (final e in entries) e.meaning],
          ['우산', '따끈따끈', '카메라', '양지, 양달', '저녁뜸'],
        );
        // The class of the deck's entry, not of another entry spelled the same.
        expect(entries[0].pos, PartOfSpeech.noun);
        expect(entries[1].pos, PartOfSpeech.adverb);
        expect(entries[0].readings, ['あまがさ']);
        expect(entries[1].readings, isEmpty);
        expect(entries.every((e) => e.included), isTrue);
        expect(result.withoutMeaning, isEmpty);
        expect(result.deck, same(deck));
      },
    );

    test(
      'asks the dictionary spelling first, with the reading and class',
      () async {
        final glossary = _Glossary({
          '日向': [
            ['양지'],
          ],
          'ひなた': [
            ['다른 뜻'],
          ],
        });

        final result = await deckDraft(
          _deck([('ひなた', 'ひなた', 9000004, '日向', null)]),
          lexicon: _lexicon,
          glossary: glossary,
        );

        expect(result.draft.entries.single.meaning, '양지');
        final first = glossary.asked.first;
        expect(first.headword, '日向');
        expect(first.readings, ['ひなた']);
        expect(first.pos, PartOfSpeech.noun);
      },
    );

    test(
      'falls back to the headword when the spelling has no meaning',
      () async {
        final glossary = _Glossary({
          'ひなた': [
            ['양달'],
          ],
        });

        final result = await deckDraft(
          _deck([('ひなた', 'ひなた', 9000004, '日向', null)]),
          lexicon: _lexicon,
          glossary: glossary,
        );

        expect(result.draft.entries.single.meaning, '양달');
      },
    );

    test('the fallback glossary only when the first has nothing', () async {
      final glossary = _Glossary({
        '雨傘': [
          ['우산'],
        ],
      });
      final fallback = _Glossary({
        '雨傘': [
          ['쓰지 않음'],
        ],
        '夕凪': [
          ['바람 잔 저녁'],
        ],
      }, source: GlossarySource.wiktionary);

      final result = await deckDraft(
        _deck([
          ('雨傘', 'あまがさ', 9000001, null, null),
          ('夕凪', 'ゆうなぎ', 9000005, null, null),
        ]),
        lexicon: _lexicon,
        glossary: glossary,
        fallback: fallback,
      );

      expect(
        [for (final e in result.draft.entries) e.meaning],
        ['우산', '바람 잔 저녁'],
      );
    });

    test(
      'the deck\'s own meaning only for a word the dictionaries miss',
      () async {
        final glossary = _Glossary({
          '雨傘': [
            ['우산'],
          ],
        });

        final result = await deckDraft(
          _deck([
            ('雨傘', 'あまがさ', 9000001, null, '쓰지 않음'),
            ('夕凪', 'ゆうなぎ', 9000005, null, '저녁뜸'),
          ]),
          lexicon: _lexicon,
          glossary: glossary,
        );

        expect(
          [for (final e in result.draft.entries) e.meaning],
          ['우산', '저녁뜸'],
        );
      },
    );

    test('words without any meaning are left out and listed', () async {
      final glossary = _Glossary({
        '雨傘': [
          ['우산'],
        ],
        '小道': [
          ['오솔길'],
        ],
      });
      final deck = _deck([
        ('雨傘', 'あまがさ', 9000001, null, null),
        ('ぽかぽか', 'ぽかぽか', 9000002, null, null),
        ('小道', 'こみち', 9000006, null, null),
        ('夕凪', 'ゆうなぎ', 9000005, null, null),
      ]);

      final result = await deckDraft(
        deck,
        lexicon: _lexicon,
        glossary: glossary,
      );

      expect([for (final e in result.draft.entries) e.headword], ['雨傘', '小道']);
      expect(
        [for (final w in result.withoutMeaning) w.headword],
        ['ぽかぽか', '夕凪'],
      );
    });

    test('reports progress up to every word', () async {
      final seen = <(int, int)>[];
      final deck = _parse(_asset()).decks.single;

      await deckDraft(
        deck,
        lexicon: _lexicon,
        glossary: _Glossary(const {}),
        onProgress: (done, total) => seen.add((done, total)),
      );

      expect(seen, isNotEmpty);
      expect(seen.last, (5, 5));
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i].$1, greaterThanOrEqualTo(seen[i - 1].$1));
        expect(seen[i].$2, 5);
      }
    });
  });

  group('addDeck', () {
    final now = DateTime(2026, 11, 13, 22);
    late InMemoryLibraryRepository library;
    late InMemoryReviewRepository reviews;
    late LibraryService service;

    final glossary = _Glossary({
      '雨傘': [
        ['우산'],
      ],
      'ぽかぽか': [
        ['따끈따끈'],
      ],
      'カメラ': [
        ['카메라'],
      ],
      '日向': [
        ['양지'],
      ],
      '小道': [
        ['오솔길'],
      ],
    });

    Future<DeckDraft> draftOf(BuiltinDeck deck) =>
        deckDraft(deck, lexicon: _lexicon, glossary: glossary);

    setUp(() {
      library = InMemoryLibraryRepository();
      reviews = InMemoryReviewRepository();
      service = LibraryService(library: library, clock: FixedClock(now));
    });

    test('makes one playlist of the deck\'s name with its words', () async {
      final deck = _parse(_asset()).decks.single;

      final result = await service.addDeck(await draftOf(deck));

      expect(result.playlist.name, 'JLPT N5 대비');
      expect(result.added, 5);
      expect(result.linked, 0);
      expect(await library.playlists(), hasLength(1));
      final words = await library.words(playlistId: result.playlist.id);
      expect(
        [for (final w in words) w.headword],
        ['雨傘', 'ぽかぽか', 'カメラ', 'ひなた', '夕凪'],
      );
      expect(words.first.meaning, '우산');
      expect(words.first.pos, PartOfSpeech.noun);
      expect(words.last.meaning, '저녁뜸');
    });

    test(
      'a word the library has is linked with its content and record',
      () async {
        final mine = Word(
          id: 'w-mine',
          headword: '雨傘',
          readings: const ['あまがさ'],
          meaning: '내가 적은 뜻',
          createdAt: now.subtract(const Duration(days: 3)),
        );
        await library.insertWords([mine]);
        final card = ReviewCard(
          wordId: 'w-mine',
          level: 3,
          dueAt: now.add(const Duration(days: 2)),
          lastReviewedAt: now.subtract(const Duration(days: 1)),
          reviewCount: 4,
        );
        await reviews.saveCard(card);

        final result = await service.addDeck(
          await draftOf(_parse(_asset()).decks.single),
        );

        expect(result.added, 4);
        expect(result.linked, 1);
        final words = await library.words(playlistId: result.playlist.id);
        expect(words.first, mine);
        expect(await reviews.card('w-mine'), card);
        expect(await library.words(), hasLength(5));
      },
    );

    test('a hidden word stays hidden', () async {
      await library.insertWords([
        Word(
          id: 'w-cam',
          headword: 'カメラ',
          readings: const [],
          meaning: '카메라',
          createdAt: now,
        ),
      ]);
      await service.hideWords(['w-cam']);

      final result = await service.addDeck(
        await draftOf(_parse(_asset()).decks.single),
      );

      final view = await service.playlistView(result.playlist.id);
      expect(view.words, hasLength(5));
      expect([for (final w in view.hiddenWords) w.id], ['w-cam']);
    });

    test('adding the deck again adds nothing twice', () async {
      final deck = _parse(_asset()).decks.single;
      final first = await service.addDeck(await draftOf(deck));

      final again = await service.addDeck(await draftOf(deck));

      expect(again.playlist.id, first.playlist.id);
      expect(again.added, 0);
      expect(again.linked, 0);
      expect(again.alreadyIn, 5);
      expect(await library.playlists(), hasLength(1));
      expect(await library.words(), hasLength(5));
      expect(await library.words(playlistId: first.playlist.id), hasLength(5));
    });

    test('a newer deck adds only its new words, at the end', () async {
      final older = _deck([
        ('雨傘', 'あまがさ', 9000001, null, null),
        ('カメラ', 'カメラ', 9000003, null, null),
      ]);
      final newer = _deck([
        ('小道', 'こみち', 9000006, null, null),
        ('雨傘', 'あまがさ', 9000001, null, null),
        ('カメラ', 'カメラ', 9000003, null, null),
      ]);
      final first = await service.addDeck(await draftOf(older));

      final again = await service.addDeck(await draftOf(newer));

      expect(again.playlist.id, first.playlist.id);
      expect(again.added, 1);
      expect(again.alreadyIn, 2);
      final words = await library.words(playlistId: first.playlist.id);
      expect([for (final w in words) w.headword], ['雨傘', 'カメラ', '小道']);
    });

    test('a playlist the learner named the same is the one added to', () async {
      final mine = await service.createPlaylist(' jlpt Ｎ5 대비 ');

      final result = await service.addDeck(
        await draftOf(_parse(_asset()).decks.single),
      );

      expect(result.playlist.id, mine.id);
      expect(await library.playlists(), hasLength(1));
    });
  });

  group('studying an added deck (B4)', () {
    final now = DateTime(2026, 11, 13, 22);

    test('its words are new cards of the playlist, in deck order', () async {
      final library = InMemoryLibraryRepository();
      final reviews = InMemoryReviewRepository();
      final service = LibraryService(library: library, clock: FixedClock(now));
      final draft = await deckDraft(
        _parse(_asset()).decks.single,
        lexicon: _lexicon,
        glossary: _Glossary({
          '雨傘': [
            ['우산'],
          ],
          'ぽかぽか': [
            ['따끈따끈'],
          ],
          'カメラ': [
            ['카메라'],
          ],
          '日向': [
            ['양지'],
          ],
        }),
      );
      final added = await service.addDeck(draft);
      final study = StudyService(
        library: library,
        reviews: reviews,
        scheduler: const LeitnerFourStepScheduler(),
        clock: FixedClock(now),
      );

      for (final mode in [StudyMode.meaning, StudyMode.recall]) {
        final session = await study.startSession(
          scope: PlaylistOnly(added.playlist.id),
          mode: mode,
          size: const AllCards(),
        );
        expect(
          [for (final i in session.queue) i.word.headword],
          ['雨傘', 'ぽかぽか', 'カメラ', 'ひなた', '夕凪'],
          reason: '$mode',
        );
        expect(session.queue.every((i) => i.before == null), isTrue);
      }
      final modes = await study.availableModes(speechAvailable: true);
      expect(modes, containsAll(StudyMode.values));
    });

    test(
      'a saved deck word finds its entry\'s example like any word',
      () async {
        final library = InMemoryLibraryRepository();
        final service = LibraryService(
          library: library,
          clock: FixedClock(now),
        );
        final added = await service.addDeck(
          await deckDraft(
            _parse(_asset()).decks.single,
            lexicon: _lexicon,
            glossary: _Glossary({
              '雨傘': [
                ['우산'],
              ],
              'ぽかぽか': [
                ['따끈따끈'],
              ],
              'カメラ': [
                ['카메라'],
              ],
              '日向': [
                ['양지'],
              ],
            }),
          ),
        );
        final words = await library.words(playlistId: added.playlist.id);
        const examples = _Examples({
          9000001: '雨傘を持って出かけた。',
          9000101: '使わない文。',
          9000002: '春の日はぽかぽかする。',
        });

        final kasa = await cardExampleOf(
          words[0],
          lexicon: _lexicon,
          examples: examples,
        );
        final poka = await cardExampleOf(
          words[1],
          lexicon: _lexicon,
          examples: examples,
        );

        expect(kasa?.ja, '雨傘を持って出かけた。');
        expect(kasa?.origin, ExampleOrigin.tatoeba);
        expect(poka?.ja, '春の日はぽかぽかする。');
      },
    );
  });
}
