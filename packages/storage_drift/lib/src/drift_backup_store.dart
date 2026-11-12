import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// Called inside a restore's transaction after the old rows are gone and
/// the words are in, before the rest (tests use it to make a restore fail
/// halfway).
typedef RestoreHook = Future<void> Function();

/// Every table of the app's SQLite file as one backup: read in one
/// transaction, replaced in one transaction.
final class DriftBackupStore implements BackupStore {
  DriftBackupStore(this._db, {RestoreHook? onHalfway}) : _onHalfway = onHalfway;

  final ShioriDatabase _db;
  final RestoreHook? _onHalfway;

  @override
  Future<BackupData> read() => _db.transaction(() async {
    final words = await _db.select(_db.words).get();
    final playlists = await _db.select(_db.playlists).get();
    final entries = await _db.select(_db.playlistWords).get();
    final cards = await _db.select(_db.reviewCards).get();
    final logs = await (_db.select(
      _db.reviewLogs,
    )..orderBy([(l) => OrderingTerm.asc(l.id)])).get();
    final settings = await _db.select(_db.settings).get();
    return BackupData(
      words: [for (final w in words) _word(w)],
      playlists: [
        for (final p in playlists)
          BackupPlaylist(
            id: p.id,
            name: p.name,
            createdAt: p.createdAt,
            position: p.position,
          ),
      ],
      playlistWords: [
        for (final e in entries)
          BackupPlaylistWord(
            playlistId: e.playlistId,
            wordId: e.wordId,
            position: e.position,
            addedAt: e.addedAt,
          ),
      ],
      cards: [
        for (final c in cards)
          ReviewCard(
            wordId: c.wordId,
            scope: CardScope.fromKey(c.scope),
            mode: c.mode,
            level: c.level,
            dueAt: c.dueAt,
            lastReviewedAt: c.lastReviewedAt,
            reviewCount: c.reviewCount,
            lapseCount: c.lapseCount,
          ),
      ],
      logs: [
        for (final l in logs)
          BackupLog(
            id: l.id,
            scope: CardScope.fromKey(l.scope),
            mode: l.mode,
            wordId: l.wordId,
            answer: l.answer,
            at: l.at,
            levelBefore: l.levelBefore,
            levelAfter: l.levelAfter,
            retriesInSession: l.retriesInSession,
          ),
      ],
      settings: {for (final s in settings) s.key: s.value},
    );
  });

  /// Children before parents out, parents before children in (foreign keys
  /// are on). Presses keep their ids, so their order stays; the press id
  /// counter starts again after the largest restored id.
  @override
  Future<void> replaceAll(BackupData data) => _db.transaction(() async {
    await _db.batch((b) {
      b
        ..deleteAll(_db.playlistWords)
        ..deleteAll(_db.reviewCards)
        ..deleteAll(_db.reviewLogs)
        ..deleteAll(_db.playlists)
        ..deleteAll(_db.words)
        ..deleteAll(_db.settings)
        ..insertAll(_db.words, [for (final w in data.words) _wordRow(w)]);
    });
    await _onHalfway?.call();
    await _db.batch((b) {
      b
        ..insertAll(_db.playlists, [
          for (final p in data.playlists)
            PlaylistsCompanion.insert(
              id: p.id,
              name: p.name,
              createdAt: p.createdAt,
              position: p.position,
            ),
        ])
        ..insertAll(_db.playlistWords, [
          for (final e in data.playlistWords)
            PlaylistWordsCompanion.insert(
              playlistId: e.playlistId,
              wordId: e.wordId,
              position: e.position,
              addedAt: e.addedAt,
            ),
        ])
        ..insertAll(_db.reviewCards, [
          for (final c in data.cards)
            ReviewCardsCompanion.insert(
              scope: c.scope.key,
              mode: Value(c.mode),
              wordId: c.wordId,
              level: c.level,
              dueAt: c.dueAt,
              lastReviewedAt: c.lastReviewedAt,
              reviewCount: c.reviewCount,
              lapseCount: c.lapseCount,
            ),
        ])
        ..insertAll(_db.reviewLogs, [
          for (final l in data.logs)
            ReviewLogsCompanion.insert(
              id: Value(l.id),
              scope: l.scope.key,
              mode: Value(l.mode),
              wordId: l.wordId,
              answer: l.answer,
              at: l.at,
              levelBefore: l.levelBefore,
              levelAfter: l.levelAfter,
              retriesInSession: l.retriesInSession,
            ),
        ])
        ..insertAll(_db.settings, [
          for (final MapEntry(:key, :value) in data.settings.entries)
            SettingsCompanion.insert(key: key, value: value),
        ]);
    });
    // The next press id follows the restored presses, not whatever the file
    // held before (SQLite takes the largest id when the row is missing).
    await _db.customStatement(
      "DELETE FROM sqlite_sequence WHERE name = 'review_logs'",
    );
  });
}

BackupWord _word(WordRow r) => BackupWord(
  id: r.id,
  key: r.key,
  headword: r.headword,
  readings: r.readings,
  pos: r.pos,
  meaning: r.meaning,
  exampleJa: r.exampleJa,
  exampleKo: r.exampleKo,
  createdAt: r.createdAt,
  hiddenAt: r.hiddenAt,
);

WordsCompanion _wordRow(BackupWord w) => WordsCompanion.insert(
  id: w.id,
  key: w.key,
  headword: w.headword,
  readings: w.readings,
  pos: Value(w.pos),
  meaning: w.meaning,
  exampleJa: Value(w.exampleJa),
  exampleKo: Value(w.exampleKo),
  createdAt: w.createdAt,
  hiddenAt: Value(w.hiddenAt),
);
