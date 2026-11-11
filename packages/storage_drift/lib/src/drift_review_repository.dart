import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/chunks.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// Learning-state storage in SQLite: review cards and the press log, by
/// `CardScope` (`scope` column: `''` shared, `p:<id>` one playlist) and
/// `StudyMode` (`mode` column).
final class DriftReviewRepository implements ReviewRepository {
  DriftReviewRepository(this._db);

  final ShioriDatabase _db;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  @override
  Future<ReviewCard?> card(
    String wordId, {
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) async {
    final row =
        await (_db.select(_db.reviewCards)
              ..where((c) => _record(c, scope, mode) & c.wordId.equals(wordId)))
            .getSingleOrNull();
    return row == null ? null : _card(row);
  }

  @override
  Future<Map<String, ReviewCard>> cards({
    Iterable<String>? wordIds,
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) async {
    final rows = wordIds == null
        ? await (_db.select(
            _db.reviewCards,
          )..where((c) => _record(c, scope, mode))).get()
        : await _cardsIn(wordIds.toSet().toList(), scope, mode);
    return Map.unmodifiable({for (final r in rows) r.wordId: _card(r)});
  }

  /// Several `IN` queries read in one transaction, so a write cannot land
  /// between them.
  Future<List<CardRow>> _cardsIn(
    List<String> ids,
    CardScope scope,
    StudyMode mode,
  ) => _db.transaction(() async {
    final rows = <CardRow>[];
    for (final chunk in chunked(ids)) {
      rows.addAll(
        await (_db.select(
          _db.reviewCards,
        )..where((c) => _record(c, scope, mode) & c.wordId.isIn(chunk))).get(),
      );
    }
    return rows;
  });

  @override
  Future<void> saveCard(ReviewCard card) => _db
      .into(_db.reviewCards)
      .insertOnConflictUpdate(
        CardRow(
          scope: card.scope.key,
          mode: card.mode,
          wordId: card.wordId,
          level: card.level,
          dueAt: card.dueAt,
          lastReviewedAt: card.lastReviewedAt,
          reviewCount: card.reviewCount,
          lapseCount: card.lapseCount,
        ),
      );

  @override
  Future<void> addLog(ReviewLog log) => _db
      .into(_db.reviewLogs)
      .insert(
        ReviewLogsCompanion.insert(
          scope: log.scope.key,
          mode: Value(log.mode),
          wordId: log.wordId,
          answer: log.answer,
          at: log.at,
          levelBefore: log.levelBefore,
          levelAfter: log.levelAfter,
          retriesInSession: log.retriesInSession,
        ),
      );

  /// Reads, then deletes, each run of ids in one transaction, so the cards
  /// returned are the ones removed.
  @override
  Future<List<ReviewCard>> deleteCards(
    Iterable<String> wordIds, {
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) {
    final ids = wordIds.toSet().toList();
    return _db.transaction(() async {
      final removed = <ReviewCard>[];
      for (final chunk in chunked(ids)) {
        Expression<bool> named($ReviewCardsTable c) =>
            _record(c, scope, mode) & c.wordId.isIn(chunk);
        final rows = await (_db.select(_db.reviewCards)..where(named)).get();
        await (_db.delete(_db.reviewCards)..where(named)).go();
        removed.addAll(rows.map(_card));
      }
      return List.unmodifiable(removed);
    });
  }

  @override
  Future<int> deleteAllCards({CardScope? scope, StudyMode? mode}) {
    final query = _db.delete(_db.reviewCards);
    if (scope != null) query.where((c) => c.scope.equals(scope.key));
    if (mode != null) query.where((c) => c.mode.equalsValue(mode));
    return query.go();
  }

  /// Oldest first; presses at the same instant in the order they were added.
  /// Sorting by `at` lets the `since` filter use the `review_logs_by_time`
  /// index (the row id rides along in it). A stored scope that is not one
  /// fails with a [FormatException].
  @override
  Future<List<ReviewLog>> logs({
    DateTime? since,
    CardScope? scope,
    StudyMode? mode,
  }) async {
    final query = _db.select(_db.reviewLogs)
      ..orderBy([(l) => OrderingTerm.asc(l.at), (l) => OrderingTerm.asc(l.id)]);
    if (since != null) {
      query.where(
        (l) => l.at.isBiggerOrEqualValue(since.microsecondsSinceEpoch),
      );
    }
    if (scope != null) query.where((l) => l.scope.equals(scope.key));
    if (mode != null) query.where((l) => l.mode.equalsValue(mode));
    final rows = await query.get();
    return List.unmodifiable(
      rows.map(
        (r) => ReviewLog(
          wordId: r.wordId,
          answer: r.answer,
          at: r.at,
          levelBefore: r.levelBefore,
          levelAfter: r.levelAfter,
          retriesInSession: r.retriesInSession,
          scope: CardScope.fromKey(r.scope),
          mode: r.mode,
        ),
      ),
    );
  }
}

ReviewCard _card(CardRow r) => ReviewCard(
  wordId: r.wordId,
  level: r.level,
  dueAt: r.dueAt,
  lastReviewedAt: r.lastReviewedAt,
  reviewCount: r.reviewCount,
  lapseCount: r.lapseCount,
  scope: CardScope.fromKey(r.scope),
  mode: r.mode,
);

/// The cards of one record: [scope] and [mode].
Expression<bool> _record(
  $ReviewCardsTable c,
  CardScope scope,
  StudyMode mode,
) => c.scope.equals(scope.key) & c.mode.equalsValue(mode);
