import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/ports/clock.dart';
import 'package:shiori_core/src/ports/hidden_word_repository.dart';
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
    this.hiddenCount = 0,
  });

  /// Review cards whose time has come, hidden words left out.
  final int dueCount;

  /// Words never studied, hidden words left out.
  final int newCount;

  /// 알고있음 presses since the current study day began.
  final int knownToday;

  /// Every word, hidden ones too.
  final int wordCount;

  /// Of [wordCount], the words the learner hid.
  final int hiddenCount;
}

/// Study use cases: summary, building a session, answering a card, hiding a
/// card the learner already knows.
final class StudyService {
  /// [hidden] defaults to [library] when that block also hides words (both
  /// stock blocks do).
  StudyService({
    required this.library,
    required this.reviews,
    required this.scheduler,
    required this.clock,
    this.settings = const StudySettings(),
    this.builder = const SessionBuilder(),
    HiddenWordRepository? hidden,
  }) : calendar = StudyCalendar.checked(settings.dayStartHour),
       hidden =
           hidden ??
           switch (library) {
             final HiddenWordRepository h => h,
             _ => null,
           };

  final LibraryRepository library;

  /// Where 이미 알아요 hides words; null when no block can.
  final HiddenWordRepository? hidden;
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
    final shown = {
      for (final w in words)
        if (!w.isHidden) w.id,
    };
    final cards = await reviews.cards(wordIds: ids);
    final todayLogs = await reviews.logs(since: calendar.startOfStudyDay(now));
    return StudySummary(
      dueCount: cards.values
          .where((c) => shown.contains(c.wordId) && c.isDue(now))
          .length,
      newCount: shown.where((id) => !cards.containsKey(id)).length,
      // Presses made before a word was hidden still happened today.
      knownToday: todayLogs
          .where((l) => l.answer == Answer.known && ids.contains(l.wordId))
          .length,
      wordCount: words.length,
      hiddenCount: words.length - shown.length,
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

  /// Applies [answer] to the current card, stores the new card and the log
  /// in one transaction, and returns the next session state.
  Future<StudySession> answer(StudySession session, Answer answer) async {
    final item = session.current;
    if (item == null) throw StateError('the session is finished');
    final now = clock.now();
    return reviews.transaction(() => _record(session, item, answer, now));
  }

  Future<StudySession> _record(
    StudySession session,
    SessionItem item,
    Answer answer,
    DateTime now,
  ) async {
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

  /// 이미 알아요: hides the current card's word and moves on. The card and the
  /// log are not touched. Nothing changes when hiding fails.
  Future<StudySession> hide(StudySession session) async {
    final item = session.current;
    if (item == null) throw StateError('the session is finished');
    final now = clock.now();
    await _hidden.hideWords([item.word.id], at: now);
    return session.afterHidden(at: now);
  }

  /// Undoes [hide] for [item]: shows its word again and puts it back as the
  /// current card of [session].
  Future<StudySession> unhide(StudySession session, SessionItem item) async {
    await _hidden.unhideWords([item.word.id]);
    return session.restored(item);
  }

  HiddenWordRepository get _hidden =>
      hidden ??
      (throw StateError('no HiddenWordRepository: words cannot be hidden'));

  /// Interval for the 알고있음 button of [item].
  Duration previewKnown(SessionItem item) =>
      scheduler.previewKnown(before: item.before, retries: item.retries);
}
