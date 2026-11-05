import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/ports/repositories.dart';
import 'package:shiori_core/src/storage/in_memory_transactions.dart';

/// Keeps learning state in memory (lost when the app quits). Used by tests;
/// the app stores it in SQLite (`packages/storage_drift`).
final class InMemoryReviewRepository implements ReviewRepository {
  final Map<String, ReviewCard> _cards = {};
  final List<ReviewLog> _logs = [];

  late final _tx = InMemoryTransactions<(Map<String, ReviewCard>, int)>(
    // Logs are only appended, so their length is enough to roll back.
    snapshot: () => (Map.of(_cards), _logs.length),
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
  Future<ReviewCard?> card(String wordId) => _tx.run(() => _cards[wordId]);

  @override
  Future<Map<String, ReviewCard>> cards({Iterable<String>? wordIds}) => _tx.run(
    () => Map<String, ReviewCard>.unmodifiable(
      wordIds == null ? _cards : {for (final id in wordIds) id: ?_cards[id]},
    ),
  );

  @override
  Future<void> saveCard(ReviewCard card) =>
      _tx.run(() => _cards[card.wordId] = card);

  @override
  Future<void> addLog(ReviewLog log) => _tx.run(() => _logs.add(log));

  @override
  Future<List<ReviewLog>> logs({DateTime? since}) => _tx.run(() {
    // Oldest first; presses at the same instant keep the order they were added.
    final picked =
        [
          for (final (i, l) in _logs.indexed)
            if (since == null || !l.at.isBefore(since)) (i, l),
        ]..sort((a, b) {
          final byTime = a.$2.at.compareTo(b.$2.at);
          return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
        });
    return List<ReviewLog>.unmodifiable(picked.map((p) => p.$2));
  });
}
