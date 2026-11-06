import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/study/study_session.dart';

/// Fills a session up to [goal]: due reviews first (oldest due first),
/// then new words in textbook order (for example 복습 4 + 새 단어 6).
/// Hidden words (이미 알아요) are left out; their cards wait for them.
final class SessionBuilder {
  const SessionBuilder();

  StudySession build({
    required List<Word> words,
    required Map<String, ReviewCard> cards,
    required DateTime now,
    required int goal,
  }) {
    final shown = [
      for (final w in words)
        if (!w.isHidden) w,
    ];
    final due = [
      for (final p in stableSorted([
        for (final w in shown)
          if (cards[w.id] case final card? when card.isDue(now))
            (word: w, card: card),
      ], (a, b) => a.card.dueAt.compareTo(b.card.dueAt)))
        SessionItem(word: p.word, before: p.card),
    ];
    final fresh = [
      for (final w in shown)
        if (!cards.containsKey(w.id)) SessionItem(word: w, before: null),
    ];
    final take = goal < 0 ? 0 : goal;
    final picked = [
      ...due.take(take),
      ...fresh.take(take - due.take(take).length),
    ];
    return StudySession(
      queue: List.unmodifiable(picked),
      total: picked.length,
      startedAt: now,
    );
  }

  /// 더 학습하기: up to [goal] cards whose review time has not come yet,
  /// lowest level first, then the earliest review, then the words' order.
  /// Due reviews, new words and hidden words are left out.
  StudySession buildMore({
    required List<Word> words,
    required Map<String, ReviewCard> cards,
    required DateTime now,
    required int goal,
  }) {
    final waiting = stableSorted(
      [
        for (final w in words)
          if (cards[w.id] case final card? when !w.isHidden && !card.isDue(now))
            (word: w, card: card),
      ],
      (a, b) {
        final byLevel = a.card.level.compareTo(b.card.level);
        return byLevel != 0 ? byLevel : a.card.dueAt.compareTo(b.card.dueAt);
      },
    );
    final picked = [
      for (final p in waiting.take(goal < 0 ? 0 : goal))
        SessionItem(word: p.word, before: p.card, ahead: true),
    ];
    return StudySession(
      queue: List.unmodifiable(picked),
      total: picked.length,
      startedAt: now,
    );
  }
}
