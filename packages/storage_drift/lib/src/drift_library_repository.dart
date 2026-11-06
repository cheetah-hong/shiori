import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/chunks.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// Library storage in SQLite: words (each once, by `words.key`), playlists
/// and their entries (`playlist_words`), and which words the learner hid
/// (`words.hidden_at`).
final class DriftLibraryRepository
    implements LibraryRepository, HiddenWordRepository {
  DriftLibraryRepository(this._db);

  final ShioriDatabase _db;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  // ------------------------------------------------------------- words

  @override
  Future<List<Word>> words({String? playlistId}) =>
      _words(playlistId: playlistId);

  /// The words of [playlistId] in its order, or every word in some playlist
  /// (or, with [listedOnly] false, every word) oldest first.
  Future<List<Word>> _words({
    String? playlistId,
    bool listedOnly = true,
    bool hiddenOnly = false,
  }) async {
    final w = _db.words;
    final pw = _db.playlistWords;
    if (playlistId != null) {
      final query =
          _db.select(w).join([
              innerJoin(pw, pw.wordId.equalsExp(w.id), useColumns: false),
            ])
            ..where(pw.playlistId.equals(playlistId))
            // A word put back by an undo keeps its old place; if another word
            // took that place meanwhile, the earlier added comes first.
            ..orderBy([
              OrderingTerm.asc(pw.position),
              OrderingTerm.asc(pw.addedAt),
              OrderingTerm.asc(pw.wordId),
            ]);
      if (hiddenOnly) query.where(w.hiddenAt.isNotNull());
      final rows = await query.get();
      return List.unmodifiable(rows.map((r) => _word(r.readTable(w))));
    }
    final query = _db.select(w)
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (listedOnly) {
      query.where(
        (t) => t.id.isInQuery(_db.selectOnly(pw)..addColumns([pw.wordId])),
      );
    }
    if (hiddenOnly) query.where((t) => t.hiddenAt.isNotNull());
    return List.unmodifiable((await query.get()).map(_word));
  }

  @override
  Future<Word?> word(String id) async {
    final row = await (_db.select(
      _db.words,
    )..where((w) => w.id.equals(id))).getSingleOrNull();
    return row == null ? null : _word(row);
  }

  /// Several `IN` queries read in one transaction, so a write cannot land
  /// between them.
  @override
  Future<Map<String, Word>> wordsByKey(Iterable<String> keys) async {
    final wanted = keys.toSet().toList();
    if (wanted.isEmpty) return const {};
    final rows = await _db.transaction(() async {
      final rows = <WordRow>[];
      for (final chunk in chunked(wanted)) {
        rows.addAll(
          await (_db.select(_db.words)..where((w) => w.key.isIn(chunk))).get(),
        );
      }
      return rows;
    });
    return Map.unmodifiable({for (final r in rows) r.key: _word(r)});
  }

  /// Checks every key and id first, then writes, in one transaction: a
  /// clash leaves the library as it was.
  @override
  Future<void> insertWords(List<Word> words) async {
    if (words.isEmpty) return;
    final w = _db.words;
    await _db.transaction(() async {
      final keys = <String>{};
      final ids = <String>{};
      final clashes = <String>[];
      for (final word in words) {
        if (!keys.add(word.key) || !ids.add(word.id)) clashes.add(word.key);
      }
      final takenKeys = <String>{};
      final takenIds = <String>{};
      for (final chunk in chunked(keys.toList())) {
        final rows =
            await (_db.selectOnly(w)
                  ..addColumns([w.key])
                  ..where(w.key.isIn(chunk)))
                .map((r) => r.read(w.key))
                .get();
        takenKeys.addAll(rows.nonNulls);
      }
      for (final chunk in chunked(ids.toList())) {
        final rows =
            await (_db.selectOnly(w)
                  ..addColumns([w.id])
                  ..where(w.id.isIn(chunk)))
                .map((r) => r.read(w.id))
                .get();
        takenIds.addAll(rows.nonNulls);
      }
      for (final word in words) {
        if (takenKeys.contains(word.key) || takenIds.contains(word.id)) {
          clashes.add(word.key);
        }
      }
      if (clashes.isNotEmpty) throw DuplicateWordException(clashes);
      await _db.batch(
        (b) => b.insertAll(w, words.map(_newWord), mode: InsertMode.insert),
      );
    });
  }

  // ------------------------------------------------------------- playlists

  @override
  Future<List<Playlist>> playlists() async {
    final rows = await (_db.select(
      _db.playlists,
    )..orderBy(_playlistOrder)).get();
    return List.unmodifiable(rows.map(_playlist));
  }

  static final _playlistOrder = <OrderClauseGenerator<$PlaylistsTable>>[
    (p) => OrderingTerm.asc(p.position),
    (p) => OrderingTerm.asc(p.createdAt),
    (p) => OrderingTerm.asc(p.id),
  ];

  @override
  Future<Playlist?> playlist(String id) async {
    final row = await (_db.select(
      _db.playlists,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _playlist(row);
  }

  @override
  Future<void> savePlaylist(Playlist playlist) => _db
      .into(_db.playlists)
      .insertOnConflictUpdate(
        PlaylistRow(
          id: playlist.id,
          name: playlist.name,
          createdAt: playlist.createdAt,
          position: playlist.position,
        ),
      );

  /// The entries go first (the foreign key would take them too; this does
  /// not depend on `PRAGMA foreign_keys`). Words are never deleted.
  @override
  Future<void> deletePlaylist(String id) => _db.transaction(() async {
    await (_db.delete(
      _db.playlistWords,
    )..where((e) => e.playlistId.equals(id))).go();
    await (_db.delete(_db.playlists)..where((p) => p.id.equals(id))).go();
  });

  /// One query: playlists left-joined to their entries and words, grouped
  /// by playlist. A playlist without words comes back as one row counting 0.
  @override
  Future<List<PlaylistStats>> playlistStats() async {
    final p = _db.playlists;
    final pw = _db.playlistWords;
    final w = _db.words;
    final count = pw.wordId.count();
    // COUNT of a column counts the rows where it is not NULL.
    final hidden = w.hiddenAt.count();
    final last = pw.addedAt.max();
    final query =
        _db.select(p).join([
            leftOuterJoin(pw, pw.playlistId.equalsExp(p.id), useColumns: false),
            leftOuterJoin(w, w.id.equalsExp(pw.wordId), useColumns: false),
          ])
          ..addColumns([count, hidden, last])
          ..groupBy([p.id])
          ..orderBy([
            OrderingTerm.asc(p.position),
            OrderingTerm.asc(p.createdAt),
            OrderingTerm.asc(p.id),
          ]);
    final rows = await query.get();
    return List.unmodifiable([
      for (final r in rows)
        PlaylistStats(
          playlist: _playlist(r.readTable(p)),
          wordCount: r.read(count) ?? 0,
          hiddenCount: r.read(hidden) ?? 0,
          lastAddedAt: switch (r.read(last)) {
            final int us => DateTime.fromMicrosecondsSinceEpoch(us),
            null => null,
          },
        ),
    ]);
  }

  /// Checks the playlist and every word, then appends, in one transaction.
  @override
  Future<void> addToPlaylist(
    String playlistId,
    List<String> wordIds, {
    required DateTime at,
  }) => _db.transaction(() async {
    if (await playlist(playlistId) == null) {
      throw PlaylistNotFoundException(playlistId);
    }
    final unique = wordIds.toSet().toList();
    final found = await _existingWordIds(unique);
    final missing = [
      for (final id in unique)
        if (!found.contains(id)) id,
    ];
    if (missing.isNotEmpty) throw WordNotFoundException(missing);
    final pw = _db.playlistWords;
    final held = <String>{};
    var next = 0;
    final rows =
        await (_db.selectOnly(pw)
              ..addColumns([pw.wordId, pw.position])
              ..where(pw.playlistId.equals(playlistId)))
            .get();
    for (final r in rows) {
      held.add(r.read(pw.wordId)!);
      final position = r.read(pw.position)!;
      if (position >= next) next = position + 1;
    }
    final fresh = [
      for (final id in unique)
        if (!held.contains(id)) id,
    ];
    if (fresh.isEmpty) return;
    await _db.batch(
      (b) => b.insertAll(pw, [
        for (final (i, id) in fresh.indexed)
          PlaylistWordsCompanion.insert(
            playlistId: playlistId,
            wordId: id,
            position: next + i,
            addedAt: at,
          ),
      ]),
    );
  });

  @override
  Future<List<PlaylistEntry>> removeFromPlaylist(
    String playlistId,
    Iterable<String> wordIds,
  ) => _db.transaction(() async {
    final ids = wordIds.toSet().toList();
    final pw = _db.playlistWords;
    final removed = <PlaylistEntry>[];
    for (final chunk in chunked(ids)) {
      final where = pw.playlistId.equals(playlistId) & pw.wordId.isIn(chunk);
      final rows = await (_db.select(pw)..where((_) => where)).get();
      removed.addAll(rows.map(_entry));
      await (_db.delete(pw)..where((_) => where)).go();
    }
    removed.sort((a, b) => a.position.compareTo(b.position));
    return List.unmodifiable(removed);
  });

  @override
  Future<void> restoreEntries(List<PlaylistEntry> entries) =>
      _db.transaction(() async {
        final pw = _db.playlistWords;
        for (final e in entries) {
          final held =
              await (_db.select(pw)..where(
                    (r) =>
                        r.playlistId.equals(e.playlistId) &
                        r.wordId.equals(e.wordId),
                  ))
                  .getSingleOrNull();
          if (held != null ||
              await playlist(e.playlistId) == null ||
              await word(e.wordId) == null) {
            continue;
          }
          await _db
              .into(pw)
              .insert(
                PlaylistWordsCompanion.insert(
                  playlistId: e.playlistId,
                  wordId: e.wordId,
                  position: e.position,
                  addedAt: e.addedAt,
                ),
              );
        }
      });

  @override
  Future<Map<String, Set<String>>> playlistsOf(Iterable<String> wordIds) async {
    final ids = wordIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final pw = _db.playlistWords;
    final of = <String, Set<String>>{};
    await _db.transaction(() async {
      for (final chunk in chunked(ids)) {
        final rows =
            await (_db.selectOnly(pw)
                  ..addColumns([pw.wordId, pw.playlistId])
                  ..where(pw.wordId.isIn(chunk)))
                .get();
        for (final r in rows) {
          final wordId = r.read(pw.wordId)!;
          final playlistId = r.read(pw.playlistId)!;
          of.putIfAbsent(wordId, () => <String>{}).add(playlistId);
        }
      }
    });
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in of.entries)
        key: Set<String>.unmodifiable(value),
    });
  }

  // ------------------------------------------------------------- hiding

  /// Only rows still shown are written, so a word keeps the time it was
  /// first hidden.
  @override
  Future<void> hideWords(Iterable<String> wordIds, {required DateTime at}) =>
      _setHidden(wordIds, at);

  @override
  Future<void> unhideWords(Iterable<String> wordIds) =>
      _setHidden(wordIds, null);

  @override
  Future<List<Word>> hiddenWords({String? playlistId}) =>
      _words(playlistId: playlistId, listedOnly: false, hiddenOnly: true);

  /// Checks every id, then writes, in one transaction: an unknown id or a
  /// failed write leaves every word as it was.
  Future<void> _setHidden(Iterable<String> wordIds, DateTime? at) async {
    final ids = wordIds.toSet().toList();
    if (ids.isEmpty) return;
    final w = _db.words;
    await _db.transaction(() async {
      final found = await _existingWordIds(ids);
      final missing = [
        for (final id in ids)
          if (!found.contains(id)) id,
      ];
      if (missing.isNotEmpty) throw WordNotFoundException(missing);
      for (final chunk in chunked(ids)) {
        await (_db.update(w)..where(
              (r) =>
                  r.id.isIn(chunk) &
                  (at == null ? r.hiddenAt.isNotNull() : r.hiddenAt.isNull()),
            ))
            .write(WordsCompanion(hiddenAt: Value(at)));
      }
    });
  }

  Future<Set<String>> _existingWordIds(List<String> ids) async {
    final w = _db.words;
    final found = <String>{};
    for (final chunk in chunked(ids)) {
      final rows =
          await (_db.selectOnly(w)
                ..addColumns([w.id])
                ..where(w.id.isIn(chunk)))
              .map((r) => r.read(w.id))
              .get();
      found.addAll(rows.nonNulls);
    }
    return found;
  }
}

Playlist _playlist(PlaylistRow r) => Playlist(
  id: r.id,
  name: r.name,
  createdAt: r.createdAt,
  position: r.position,
);

PlaylistEntry _entry(PlaylistWordRow r) => PlaylistEntry(
  playlistId: r.playlistId,
  wordId: r.wordId,
  position: r.position,
  addedAt: r.addedAt,
);

Word _word(WordRow r) {
  final ja = r.exampleJa, ko = r.exampleKo;
  return Word(
    id: r.id,
    headword: r.headword,
    readings: r.readings,
    pos: r.pos,
    meaning: r.meaning,
    example: ja != null && ko != null ? Example(ja: ja, ko: ko) : null,
    createdAt: r.createdAt,
    hiddenAt: r.hiddenAt,
  );
}

/// A new row for [w], stored shown (`hidden_at` is left out).
WordsCompanion _newWord(Word w) => WordsCompanion.insert(
  id: w.id,
  key: w.key,
  headword: w.headword,
  readings: w.readings,
  pos: Value(w.pos),
  meaning: w.meaning,
  exampleJa: Value(w.example?.ja),
  exampleKo: Value(w.example?.ko),
  createdAt: w.createdAt,
);
