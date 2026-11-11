import 'package:shiori_core/src/models/study_mode.dart';

/// Whose learning state a card or a press is: the word's one record shared
/// by every playlist ([shared], the only one the app uses now), or a record
/// of the word inside one playlist (for a later "per playlist" setting).
final class CardScope {
  const CardScope._(this.key);

  /// The word's record inside playlist [playlistId]. Stored as `p:<id>`.
  factory CardScope.playlist(String playlistId) {
    if (playlistId.isEmpty) {
      throw ArgumentError.value(playlistId, 'playlistId', 'must not be empty');
    }
    return CardScope._('$_playlistPrefix$playlistId');
  }

  /// The scope stored as [key]; a [FormatException] for anything else.
  factory CardScope.fromKey(String key) {
    if (key.isEmpty) return shared;
    if (key.startsWith(_playlistPrefix) &&
        key.length > _playlistPrefix.length) {
      return CardScope._(key);
    }
    throw FormatException('not a card scope', key);
  }

  /// One record per word, whatever playlists hold it. Stored as `''`.
  static const CardScope shared = CardScope._('');

  static const String _playlistPrefix = 'p:';

  /// How the scope is stored.
  final String key;

  bool get isShared => key.isEmpty;

  /// The playlist of a per-playlist scope; null for [shared].
  String? get playlistId =>
      isShared ? null : key.substring(_playlistPrefix.length);

  @override
  bool operator ==(Object other) => other is CardScope && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => isShared ? 'CardScope.shared' : 'CardScope($key)';
}

/// Learning state of one word in one [StudyMode]: memory level and next
/// review.
///
/// A word without a card (in a mode) is a new word (in that mode).
final class ReviewCard {
  const ReviewCard({
    required this.wordId,
    required this.level,
    required this.dueAt,
    required this.lastReviewedAt,
    this.reviewCount = 0,
    this.lapseCount = 0,
    this.scope = CardScope.shared,
    this.mode = StudyMode.meaning,
  });

  final String wordId;

  /// Whose record this is ([CardScope.shared] unless per-playlist).
  final CardScope scope;

  /// The way of studying this record belongs to.
  final StudyMode mode;

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
    CardScope? scope,
    StudyMode? mode,
  }) => ReviewCard(
    wordId: wordId,
    level: level ?? this.level,
    dueAt: dueAt ?? this.dueAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    reviewCount: reviewCount ?? this.reviewCount,
    lapseCount: lapseCount ?? this.lapseCount,
    scope: scope ?? this.scope,
    mode: mode ?? this.mode,
  );

  @override
  bool operator ==(Object other) =>
      other is ReviewCard &&
      other.wordId == wordId &&
      other.scope == scope &&
      other.mode == mode &&
      other.level == level &&
      other.dueAt == dueAt &&
      other.lastReviewedAt == lastReviewedAt &&
      other.reviewCount == reviewCount &&
      other.lapseCount == lapseCount;

  @override
  int get hashCode => Object.hash(
    wordId,
    scope,
    mode,
    level,
    dueAt,
    lastReviewedAt,
    reviewCount,
    lapseCount,
  );

  @override
  String toString() => 'ReviewCard($wordId ${mode.name} L$level due $dueAt)';
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
    this.scope = CardScope.shared,
    this.mode = StudyMode.meaning,
  });

  final String wordId;

  /// The record the press went to (as `ReviewCard.scope`).
  final CardScope scope;

  /// The way of studying the press was made in (as `ReviewCard.mode`).
  final StudyMode mode;
  final Answer answer;
  final DateTime at;

  /// Level before the session; 0 for a new word.
  final int levelBefore;
  final int levelAfter;
  final int retriesInSession;
}
