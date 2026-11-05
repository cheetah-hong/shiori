import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/ports/repositories.dart';

/// First storage block for learning state (lost when the app quits).
/// Next block: drift (SQLite) behind the same interface.
final class InMemoryReviewRepository implements ReviewRepository {
  final Map<String, ReviewCard> _cards = {};
  final List<ReviewLog> _logs = [];

  @override
  Future<ReviewCard?> card(String wordId) async => _cards[wordId];

  @override
  Future<Map<String, ReviewCard>> cards({Iterable<String>? wordIds}) async {
    if (wordIds == null) return Map.unmodifiable(_cards);
    return Map.unmodifiable({for (final id in wordIds) id: ?_cards[id]});
  }

  @override
  Future<void> saveCard(ReviewCard card) async => _cards[card.wordId] = card;

  @override
  Future<void> addLog(ReviewLog log) async => _logs.add(log);

  @override
  Future<List<ReviewLog>> logs({DateTime? since}) async => List.unmodifiable(
    since == null ? _logs : _logs.where((l) => !l.at.isBefore(since)),
  );
}
