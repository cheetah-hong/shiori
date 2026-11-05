import 'package:drift/drift.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/src/chunks.dart';
import 'package:shiori_storage_drift/src/database.dart';

/// Learning-state storage in SQLite: review cards and the press log.
final class DriftReviewRepository implements ReviewRepository {
  DriftReviewRepository(this._db);

  final ShioriDatabase _db;

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  @override
  Future<ReviewCard?> card(String wordId) async {
    final row = await (_db.select(
      _db.reviewCards,
    )..where((c) => c.wordId.equals(wordId))).getSingleOrNull();
    return row == null ? null : _card(row);
  }

  @override
  Future<Map<String, ReviewCard>> cards({Iterable<String>? wordIds}) async {
    final rows = wordIds == null
        ? await _db.select(_db.reviewCards).get()
        : await _cardsIn(wordIds.toSet().toList());
    return Map.unmodifiable({for (final r in rows) r.wordId: _card(r)});
  }

  /// Several `IN` queries read in one transaction, so a write cannot land
  /// between them.
  Future<List<CardRow>> _cardsIn(List<String> ids) => _db.transaction(() async {
    final rows = <CardRow>[];
    for (final chunk in chunked(ids)) {
      rows.addAll(
        await (_db.select(
          _db.reviewCards,
        )..where((c) => c.wordId.isIn(chunk))).get(),
      );
    }
    return rows;
  });

  @override
  Future<void> saveCard(ReviewCard card) => _db
      .into(_db.reviewCards)
      .insertOnConflictUpdate(
        CardRow(
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
          wordId: log.wordId,
          answer: log.answer,
          at: log.at,
          levelBefore: log.levelBefore,
          levelAfter: log.levelAfter,
          retriesInSession: log.retriesInSession,
        ),
      );

  /// Oldest first; presses at the same instant in the order they were added.
  /// Sorting by `at` lets the `since` filter use the `review_logs_by_time`
  /// index (the row id rides along in it).
  @override
  Future<List<ReviewLog>> logs({DateTime? since}) async {
    final query = _db.select(_db.reviewLogs)
      ..orderBy([(l) => OrderingTerm.asc(l.at), (l) => OrderingTerm.asc(l.id)]);
    if (since != null) {
      query.where(
        (l) => l.at.isBiggerOrEqualValue(since.microsecondsSinceEpoch),
      );
    }
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
);
