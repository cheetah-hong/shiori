/// How many cards a session takes of the ones it can study.
sealed class SessionSize {
  const SessionSize();

  /// The cards a session of this size holds when [available] can be studied.
  int of(int available);
}

/// At most [cards] (the daily goal).
final class UpTo extends SessionSize {
  const UpTo(this.cards);

  final int cards;

  @override
  int of(int available) {
    final limit = cards < 0 ? 0 : cards;
    final count = available < 0 ? 0 : available;
    return count < limit ? count : limit;
  }

  @override
  bool operator ==(Object other) => other is UpTo && other.cards == cards;

  @override
  int get hashCode => Object.hash(UpTo, cards);

  @override
  String toString() => 'UpTo($cards)';
}

/// Every card that can be studied.
final class AllCards extends SessionSize {
  const AllCards();

  @override
  int of(int available) => available < 0 ? 0 : available;

  @override
  bool operator ==(Object other) => other is AllCards;

  @override
  int get hashCode => (AllCards).hashCode;

  @override
  String toString() => 'AllCards()';
}
