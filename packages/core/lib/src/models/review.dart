/// Learning state of one word: memory level and next review.
///
/// A word without a card is a new word.
final class ReviewCard {
  const ReviewCard({
    required this.wordId,
    required this.level,
    required this.dueAt,
    required this.lastReviewedAt,
    this.reviewCount = 0,
    this.lapseCount = 0,
  });

  final String wordId;

  /// Memory level, 1 to the scheduler's maximum (4 = 장기 기억).
  final int level;
  final DateTime dueAt;
  final DateTime lastReviewedAt;

  /// Number of times the learner pressed 알고있음 for this word.
  final int reviewCount;

  /// Number of times the learner pressed 다시 학습 for this word.
  final int lapseCount;

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  ReviewCard copyWith({
    int? level,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    int? lapseCount,
  }) => ReviewCard(
    wordId: wordId,
    level: level ?? this.level,
    dueAt: dueAt ?? this.dueAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    reviewCount: reviewCount ?? this.reviewCount,
    lapseCount: lapseCount ?? this.lapseCount,
  );

  @override
  bool operator ==(Object other) =>
      other is ReviewCard &&
      other.wordId == wordId &&
      other.level == level &&
      other.dueAt == dueAt &&
      other.lastReviewedAt == lastReviewedAt &&
      other.reviewCount == reviewCount &&
      other.lapseCount == lapseCount;

  @override
  int get hashCode => Object.hash(
    wordId,
    level,
    dueAt,
    lastReviewedAt,
    reviewCount,
    lapseCount,
  );

  @override
  String toString() => 'ReviewCard($wordId L$level due $dueAt)';
}

/// The two study buttons.
enum Answer {
  /// 다시 학습: the card goes to the back of the session.
  retry,

  /// 알고있음: the card leaves the session with a new level.
  known,
}

/// One button press in a session.
final class ReviewLog {
  const ReviewLog({
    required this.wordId,
    required this.answer,
    required this.at,
    required this.levelBefore,
    required this.levelAfter,
    required this.retriesInSession,
  });

  final String wordId;
  final Answer answer;
  final DateTime at;

  /// Level before the session; 0 for a new word.
  final int levelBefore;
  final int levelAfter;
  final int retriesInSession;
}
