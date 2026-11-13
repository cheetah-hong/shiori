// B3·B5 in the SQLite block: a built-in deck added through the app's own
// repositories is an ordinary playlist (one word per headword, adding again
// adds nothing), and a library holding one comes back from a backup file the
// same, row for row, in backup format version 1. Made-up words only.
import 'dart:convert';

import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

final _now = DateTime(2026, 11, 13, 22, 30);
const _app = BackupApp(version: '1.0.0', build: '8', schema: 5);

/// One sense per headword.
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
      KoreanSense(words: [meaning], source: GlossarySource.krdict),
  ];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

final _lexicon = InMemoryLexicon(const [
  LexiconWord(id: 9100001, kanji: ['風車'], readings: ['かざぐるま'], pos: ['n']),
  LexiconWord(id: 9100002, kanji: ['雨傘'], readings: ['あまがさ'], pos: ['n']),
  LexiconWord(id: 9100003, readings: ['ぽかぽか'], pos: ['adv']),
  LexiconWord(id: 9100004, kanji: ['夕焼け'], readings: ['ゆうやけ'], pos: ['n']),
]);

const _glossary = _Glossary({
  '風車': '바람개비',
  '雨傘': '우산',
  'ぽかぽか': '따끈따끈',
  '夕焼け': '저녁노을',
});

const _deck = BuiltinDeck(
  id: 'jlpt-n5',
  name: 'JLPT N5 대비',
  level: 'N5',
  words: [
    DeckWord(headword: '風車', reading: 'かざぐるま', entryId: 9100001),
    DeckWord(headword: '雨傘', reading: 'あまがさ', entryId: 9100002),
    DeckWord(headword: 'ぽかぽか', reading: 'ぽかぽか', entryId: 9100003),
    DeckWord(headword: '夕焼け', reading: 'ゆうやけ', entryId: 9100004),
  ],
);

Future<Map<String, List<Map<String, Object?>>>> _dump(ShioriDatabase db) async {
  const tables = {
    'words': 'id',
    'playlists': 'id',
    'playlist_words': 'playlist_id, word_id',
    'review_cards': 'scope, mode, word_id',
    'review_logs': 'id',
    'settings': 'key',
  };
  return {
    for (final MapEntry(key: table, value: order) in tables.entries)
      table: [
        for (final row
            in await db
                .customSelect('SELECT * FROM $table ORDER BY $order')
                .get())
          row.data,
      ],
  };
}

/// The deck added to [db], one word studied, one hidden.
Future<AddResult> _seed(ShioriDatabase db) async {
  final library = DriftLibraryRepository(db);
  final service = LibraryService(library: library, clock: FixedClock(_now));
  // A word the learner had before, from a page.
  await library.insertWords([
    Word(
      id: 'w-page',
      headword: '雨傘',
      readings: const ['あまがさ'],
      meaning: '비 오는 날 쓰는 우산',
      createdAt: _now.subtract(const Duration(days: 5)),
    ),
  ]);
  final result = await service.addDeck(
    await deckDraft(_deck, lexicon: _lexicon, glossary: _glossary),
  );
  final words = await library.words(playlistId: result.playlist.id);
  await DriftReviewRepository(db).saveCard(
    ReviewCard(
      wordId: words.first.id,
      level: 2,
      dueAt: _now.add(const Duration(days: 3)),
      lastReviewedAt: _now,
      reviewCount: 1,
    ),
  );
  await service.hideWords([words.last.id]);
  return result;
}

void main() {
  test(
    'B3 a deck in SQLite: one playlist, linked words, again adds nothing',
    () async {
      final db = ShioriDatabase.memory();
      addTearDown(db.close);
      final library = DriftLibraryRepository(db);
      final service = LibraryService(library: library, clock: FixedClock(_now));

      final first = await _seed(db);
      final again = await service.addDeck(
        await deckDraft(_deck, lexicon: _lexicon, glossary: _glossary),
      );

      expect(first.added, 3);
      expect(first.linked, 1);
      expect(again.playlist.id, first.playlist.id);
      expect(again.added + again.linked, 0);
      expect(again.alreadyIn, 4);
      expect(await library.playlists(), hasLength(1));
      final words = await library.words(playlistId: first.playlist.id);
      expect([for (final w in words) w.headword], ['風車', '雨傘', 'ぽかぽか', '夕焼け']);
      expect(words[1].id, 'w-page');
      expect(words[1].meaning, '비 오는 날 쓰는 우산');
      expect(words[2].readings, isEmpty);
      expect(words[0].pos, PartOfSpeech.noun);
      expect(await library.words(), hasLength(4));
    },
  );

  test(
    'B5 a library with a deck: backup file and back, row for row, v1',
    () async {
      final source = ShioriDatabase.memory();
      final target = ShioriDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _seed(source);

      final bytes = encodeBackup(
        BackupFile(
          createdAt: _now,
          app: _app,
          data: await DriftBackupStore(source).read(),
        ),
      );
      final document = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      await DriftBackupStore(target).replaceAll(decodeBackup(bytes).data);

      expect(document['version'], 1);
      expect(backupVersion, 1);
      final before = await _dump(source);
      expect(before['words'], hasLength(4));
      expect(before['playlists'], hasLength(1));
      expect(before['playlist_words'], hasLength(4));
      expect(before['review_cards'], hasLength(1));
      expect(await _dump(target), before);
    },
  );
}
