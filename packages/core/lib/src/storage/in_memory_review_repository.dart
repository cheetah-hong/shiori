import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/ports/repositories.dart';
import 'package:shiori_core/src/storage/in_memory_transactions.dart';

/// Cards keyed by scope, then word id.
typedef _Cards = Map<CardScope, Map<String, ReviewCard>>;

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
  }) => _tx.run(() => _cards[scope]?[wordId]);

  @override
  Future<Map<String, ReviewCard>> cards({
    Iterable<String>? wordIds,
    CardScope scope = CardScope.shared,
  }) => _tx.run(() {
    final inScope = _cards[scope] ?? const <String, ReviewCard>{};
    return Map<String, ReviewCard>.unmodifiable(
      wordIds == null ? inScope : {for (final id in wordIds) id: ?inScope[id]},
    );
  });

  @override
  Future<void> saveCard(ReviewCard card) =>
      _tx.run(() => (_cards[card.scope] ??= {})[card.wordId] = card);

  @override
  Future<void> addLog(ReviewLog log) => _tx.run(() => _logs.add(log));

  @override
  Future<List<ReviewLog>> logs({DateTime? since, CardScope? scope}) =>
      _tx.run(() {
        // Oldest first; presses at the same instant keep the order they
        // were added.
        final picked =
            [
              for (final (i, l) in _logs.indexed)
                if ((since == null || !l.at.isBefore(since)) &&
                    (scope == null || l.scope == scope))
                  (i, l),
            ]..sort((a, b) {
              final byTime = a.$2.at.compareTo(b.$2.at);
              return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
            });
        return List<ReviewLog>.unmodifiable(picked.map((p) => p.$2));
      });
}
