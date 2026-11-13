// E5s·E6 in the SQLite block: reading every word for 단어 찾기 stays quick
// at 8,000 words, and a library holding a changed word (new key), a word
// added by hand and a word left in no playlist by 「저장된 단어로 바꾸기」
// comes back from a backup file the same, row for row — backup format 1,
// schema 5. Made-up words only.
import 'dart:convert';

import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

final _now = DateTime(2026, 11, 14, 9, 30);
const _app = BackupApp(version: '1.0.0', build: '9', schema: 5);

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

void main() {
  test('E6 changed, typed and replaced words: backup and back, v1', () async {
    final source = ShioriDatabase.memory();
    final target = ShioriDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    final library = DriftLibraryRepository(source);
    final reviews = DriftReviewRepository(source);
    final service = LibraryService(library: library, clock: FixedClock(_now));

    final first = await service.addDraft(
      const CaptureDraft(
        entries: [
          CapturedEntry(
            headword: '試後甲',
            readings: ['しごこう'],
            pos: PartOfSpeech.noun,
            meaning: '잘못 읽은 낱말',
          ),
          CapturedEntry(
            headword: '試語乙乙',
            readings: ['しごおつ'],
            pos: null,
            meaning: '두 번 읽힌 낱말',
          ),
        ],
      ),
      to: const NewPlaylist('試語帳'),
    );
    final words = await library.words(playlistId: first.playlist.id);
    await reviews.saveCard(
      ReviewCard(
        wordId: words.first.id,
        level: 2,
        dueAt: _now.add(const Duration(days: 3)),
        lastReviewedAt: _now,
        reviewCount: 1,
      ),
    );
    await service.editWord(
      words.first.id,
      const WordEdit(
        headword: '試語甲',
        readings: ['しごこう'],
        pos: PartOfSpeech.noun,
        meaning: '고친 낱말',
        example: Example(ja: '試語甲を読む。', ko: '시험 낱말을 읽는다.'),
      ),
    );
    final typed = await service.addWord(
      const WordEdit(headword: '試語乙', readings: ['しごおつ'], meaning: '손으로'),
      to: ExistingPlaylist(first.playlist.id),
    );
    expect(typed.added, 1);
    final stored = (await library.wordsByKey([wordKey('試語乙')])).values.single;
    await service.replaceWithExisting(words.last.id, stored.id);

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
    expect(source.schemaVersion, 5);
    final before = await _dump(source);
    expect(before['words'], hasLength(3), reason: 'the replaced word stays');
    expect(before['playlist_words'], hasLength(2));
    expect([
      for (final w in before['words']!) w['key'],
    ], containsAll([wordKey('試語甲'), wordKey('試語乙'), wordKey('試語乙乙')]));
    expect(await _dump(target), before);
  });

  test('E5s every word of 8,000 is read within a second', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final library = DriftLibraryRepository(db);
    final made = [
      for (var i = 0; i < 8000; i++)
        Word(
          id: 'm$i',
          headword: '合成$i',
          readings: ['ごうせい$i'],
          meaning: '합성 낱말 $i',
          createdAt: _now.add(Duration(microseconds: i)),
        ),
    ];
    await library.insertWords(made);
    await library.savePlaylist(
      Playlist(id: 'p', name: 'p', createdAt: _now, position: 0),
    );
    await library.addToPlaylist('p', [for (final w in made) w.id], at: _now);

    final sw = Stopwatch()..start();
    final all = await library.words();
    final took = sw.elapsedMilliseconds;

    expect(all, hasLength(8000));
    expect(took, lessThanOrEqualTo(1000), reason: '${took}ms');
    expect(WordSearchIndex(all).find('合成7999').first.id, 'm7999');
  });
}
