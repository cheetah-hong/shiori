import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/models/study_mode.dart';
import 'package:shiori_core/src/ports/repositories.dart';
import 'package:shiori_core/src/storage/in_memory_transactions.dart';

/// Which record a card belongs to: its scope and its mode.
typedef _Record = (CardScope, StudyMode);

/// Cards keyed by record, then word id.
typedef _Cards = Map<_Record, Map<String, ReviewCard>>;

/// Keeps learning state in memory (lost when the app quits). Used by tests;
/// the app stores it in SQLite (`packages/storage_drift`).
final class InMemoryReviewRepository implements ReviewRepository {
  final _Cards _cards = {};
  final List<ReviewLog> _logs = [];

  late final _tx = InMemoryTransactions<(_Cards, int)>(
    // Logs are only appended, so their length is enough to roll back.
    snapshot: () => (
      {for (final MapEntry(:key, :value) in _cards.entries) key: Map.of(value)},
      _logs.length,
    ),
    restore: (state) {
      final (cards, logCount) = state;
      _cards
        ..clear()
        ..addAll(cards);
      _logs.removeRange(logCount, _logs.length);
    },
  );

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _tx.transaction(action);

  @override
  Future<ReviewCard?> card(
    String wordId, {
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) => _tx.run(() => _cards[(scope, mode)]?[wordId]);

  @override
  Future<Map<String, ReviewCard>> cards({
    Iterable<String>? wordIds,
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) => _tx.run(() {
    final inRecord = _cards[(scope, mode)] ?? const <String, ReviewCard>{};
    return Map<String, ReviewCard>.unmodifiable(
      wordIds == null
          ? inRecord
          : {for (final id in wordIds) id: ?inRecord[id]},
    );
  });

  @override
  Future<void> saveCard(ReviewCard card) => _tx.run(
    () => (_cards[(card.scope, card.mode)] ??= {})[card.wordId] = card,
  );

  @override
  Future<void> addLog(ReviewLog log) => _tx.run(() => _logs.add(log));

  @override
  Future<List<ReviewCard>> deleteCards(
    Iterable<String> wordIds, {
    CardScope scope = CardScope.shared,
    StudyMode mode = StudyMode.meaning,
  }) => _tx.run(() {
    final inRecord = _cards[(scope, mode)];
    if (inRecord == null) return const <ReviewCard>[];
    return List<ReviewCard>.unmodifiable([
      for (final id in wordIds.toSet()) ?inRecord.remove(id),
    ]);
  });

  @override
  Future<int> deleteAllCards({CardScope? scope, StudyMode? mode}) =>
      _tx.run(() {
        final picked = [
          for (final record in _cards.keys)
            if ((scope == null || record.$1 == scope) &&
                (mode == null || record.$2 == mode))
              record,
        ];
        var count = 0;
        for (final record in picked) {
          count += _cards.remove(record)?.length ?? 0;
        }
        return count;
      });

  @override
  Future<List<ReviewLog>> logs({
    DateTime? since,
    CardScope? scope,
    StudyMode? mode,
  }) => _tx.run(() {
    // Oldest first; presses at the same instant keep the order they were
    // added.
    final picked =
        [
          for (final (i, l) in _logs.indexed)
            if ((since == null || !l.at.isBefore(since)) &&
                (scope == null || l.scope == scope) &&
                (mode == null || l.mode == mode))
              (i, l),
        ]..sort((a, b) {
          final byTime = a.$2.at.compareTo(b.$2.at);
          return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
        });
    return List<ReviewLog>.unmodifiable(picked.map((p) => p.$2));
  });
}
