import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/ports/clock.dart';
import 'package:shiori_core/src/ports/repositories.dart';
import 'package:shiori_core/src/ports/review_scheduler.dart';
import 'package:shiori_core/src/study/session_builder.dart';
import 'package:shiori_core/src/study/study_calendar.dart';
import 'package:shiori_core/src/study/study_session.dart';
import 'package:shiori_core/src/study/study_settings.dart';

final class StudySummary {
  const StudySummary({
    required this.dueCount,
    required this.newCount,
    required this.knownToday,
    required this.wordCount,
  });

  /// Review cards whose time has come.
  final int dueCount;

  /// Words never studied.
  final int newCount;

  /// 알고있음 presses since the current study day began.
  final int knownToday;
  final int wordCount;
}

/// Study use cases: summary, building a session, answering a card.
final class StudyService {
  StudyService({
    required this.library,
    required this.reviews,
    required this.scheduler,
    required this.clock,
    this.settings = const StudySettings(),
    this.builder = const SessionBuilder(),
  }) : calendar = StudyCalendar.checked(settings.dayStartHour);

  final LibraryRepository library;
  final ReviewRepository reviews;
  final ReviewScheduler scheduler;
  final Clock clock;
  final StudySettings settings;
  final SessionBuilder builder;
  final StudyCalendar calendar;

  Future<StudySummary> summary({String? textbookId}) async {
    final now = clock.now();
    final words = await library.words(textbookId: textbookId);
    final ids = {for (final w in words) w.id};
    final cards = await reviews.cards(wordIds: ids);
    final todayLogs = await reviews.logs(since: calendar.startOfStudyDay(now));
    return StudySummary(
      dueCount: cards.values.where((c) => c.isDue(now)).length,
      newCount: ids.where((id) => !cards.containsKey(id)).length,
      knownToday: todayLogs
          .where((l) => l.answer == Answer.known && ids.contains(l.wordId))
          .length,
      wordCount: words.length,
    );
  }

  Future<StudySession> startSession({String? textbookId, int? goal}) async {
    final words = await library.words(textbookId: textbookId);
    final cards = await reviews.cards(wordIds: words.map((w) => w.id));
    return builder.build(
      words: words,
      cards: cards,
      now: clock.now(),
      goal: goal ?? settings.dailyGoal,
    );
  }

  /// Applies [answer] to the current card, stores the new card and the log,
  /// and returns the next session state.
  Future<StudySession> answer(StudySession session, Answer answer) async {
    final item = session.current;
    if (item == null) throw StateError('the session is finished');
    final now = clock.now();
    final wordId = item.word.id;

    switch (answer) {
      case Answer.known:
        final card = scheduler.known(
          wordId: wordId,
          before: item.before,
          retries: item.retries,
          now: now,
        );
        await reviews.saveCard(card);
        await reviews.addLog(
          ReviewLog(
            wordId: wordId,
            answer: answer,
            at: now,
            levelBefore: item.before?.level ?? 0,
            levelAfter: card.level,
            retriesInSession: item.retries,
          ),
        );
        return session.afterKnown(at: now);
      case Answer.retry:
        final card = scheduler.retry(
          wordId: wordId,
          current: await reviews.card(wordId),
          now: now,
        );
        await reviews.saveCard(card);
        await reviews.addLog(
          ReviewLog(
            wordId: wordId,
            answer: answer,
            at: now,
            levelBefore: item.before?.level ?? 0,
            levelAfter: card.level,
            retriesInSession: item.retries + 1,
          ),
        );
        return session.afterRetry();
    }
  }

  /// Interval for the 알고있음 button of [item].
  Duration previewKnown(SessionItem item) =>
      scheduler.previewKnown(before: item.before, retries: item.retries);
}
