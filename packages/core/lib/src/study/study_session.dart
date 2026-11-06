import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/review.dart';

/// A card in a session.
final class SessionItem {
  const SessionItem({
    required this.word,
    required this.before,
    this.retries = 0,
    this.ahead = false,
  });

  final Word word;

  /// The card when the session started; null for a new word.
  final ReviewCard? before;

  /// 다시 학습 presses for this card in this session.
  final int retries;

  /// A card studied before its review time (더 학습하기): 알고있음 leaves it
  /// as it was, unless it was retried in this session.
  final bool ahead;

  bool get isNew => before == null;

  SessionItem retried() => SessionItem(
    word: word,
    before: before,
    retries: retries + 1,
    ahead: ahead,
  );
}

/// One study session. Immutable: every answer returns a new session.
///
/// 다시 학습 sends the card to the back; only 알고있음 counts toward progress.
final class StudySession {
  const StudySession({
    required this.queue,
    required this.total,
    required this.startedAt,
    this.knownCount = 0,
    this.knownNewCount = 0,
    this.retryCount = 0,
    this.finishedAt,
  });

  /// Remaining cards; the first one is on screen.
  final List<SessionItem> queue;
  final int total;
  final DateTime startedAt;
  final int knownCount;

  /// Of [knownCount], how many were new words.
  final int knownNewCount;
  final int retryCount;

  /// When the last card was answered with 알고있음.
  final DateTime? finishedAt;

  /// Time spent, once finished (never negative, even if the clock moved back).
  Duration? get elapsed {
    final end = finishedAt;
    if (end == null) return null;
    final d = end.difference(startedAt);
    return d.isNegative ? Duration.zero : d;
  }

  SessionItem? get current => queue.isEmpty ? null : queue.first;
  bool get isFinished => queue.isEmpty;
  double get progress => total == 0 ? 0 : knownCount / total;
  int get knownReviewCount => knownCount - knownNewCount;

  /// [at] is recorded as [finishedAt] when this was the last card.
  StudySession afterKnown({DateTime? at}) {
    final item = _requireCurrent();
    return _next(
      queue: queue.skip(1),
      knownCount: knownCount + 1,
      knownNewCount: knownNewCount + (item.isNew ? 1 : 0),
      retryCount: retryCount,
      finishedAt: queue.length == 1 ? at : null,
    );
  }

  StudySession afterRetry() {
    final item = _requireCurrent();
    return _next(
      queue: [...queue.skip(1), item.retried()],
      knownCount: knownCount,
      knownNewCount: knownNewCount,
      retryCount: retryCount + 1,
    );
  }

  /// The current card leaves the session without an answer (이미 알아요):
  /// it no longer counts toward [total]. [at] is recorded as [finishedAt]
  /// when no card is left.
  StudySession afterHidden({DateTime? at}) {
    _requireCurrent();
    return _next(
      queue: queue.skip(1),
      total: total - 1,
      knownCount: knownCount,
      knownNewCount: knownNewCount,
      retryCount: retryCount,
      finishedAt: queue.length == 1 ? at : null,
    );
  }

  /// [item] comes back as the current card (undoing [afterHidden]).
  StudySession restored(SessionItem item) => _next(
    queue: [item, ...queue],
    total: total + 1,
    knownCount: knownCount,
    knownNewCount: knownNewCount,
    retryCount: retryCount,
  );

  SessionItem _requireCurrent() {
    final item = current;
    if (item == null) throw StateError('the session is finished');
    return item;
  }

  StudySession _next({
    required Iterable<SessionItem> queue,
    int? total,
    required int knownCount,
    required int knownNewCount,
    required int retryCount,
    DateTime? finishedAt,
  }) => StudySession(
    queue: List.unmodifiable(queue),
    total: total ?? this.total,
    startedAt: startedAt,
    knownCount: knownCount,
    knownNewCount: knownNewCount,
    retryCount: retryCount,
    finishedAt: finishedAt,
  );
}
