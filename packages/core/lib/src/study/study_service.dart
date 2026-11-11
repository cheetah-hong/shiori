import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/review.dart';
import 'package:shiori_core/src/models/study_mode.dart';
import 'package:shiori_core/src/models/study_preferences.dart';
import 'package:shiori_core/src/ports/clock.dart';
import 'package:shiori_core/src/ports/hidden_word_repository.dart';
import 'package:shiori_core/src/ports/repositories.dart';
import 'package:shiori_core/src/ports/review_scheduler.dart';
import 'package:shiori_core/src/study/choice_maker.dart';
import 'package:shiori_core/src/study/session_builder.dart';
import 'package:shiori_core/src/study/study_calendar.dart';
import 'package:shiori_core/src/study/study_session.dart';
import 'package:shiori_core/src/study/study_settings.dart';

/// Which words a summary or a session is about.
sealed class StudyScope {
  const StudyScope();
}

/// Every word in at least one playlist (전체 복습).
final class AllWords extends StudyScope {
  const AllWords();

  @override
  bool operator ==(Object other) => other is AllWords;

  @override
  int get hashCode => (AllWords).hashCode;
}

/// The words of one playlist.
final class PlaylistOnly extends StudyScope {
  const PlaylistOnly(this.playlistId);

  final String playlistId;

  @override
  bool operator ==(Object other) =>
      other is PlaylistOnly && other.playlistId == playlistId;

  @override
  int get hashCode => playlistId.hashCode;
}

final class StudySummary {
  const StudySummary({
    required this.dueCount,
    required this.newCount,
    required this.knownToday,
    required this.wordCount,
    this.hiddenCount = 0,
    this.aheadCount = 0,
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

  /// Cards whose review time has not come (what 더 학습하기 can bring
  /// forward), hidden words left out.
  final int aheadCount;
}

/// Study use cases: summary, building a session (today's or 더 학습하기),
/// answering a card, hiding a card the learner already knows, and making
/// learned words new again (one word or all).
///
/// Writes run in one transaction each; resetting removes cards only, never
/// the press log or a word's hidden state.
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
    this.preferences = const StudyPreferences(),
    this.choiceMaker = const ChoiceMaker(),
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

  /// Picks the options of 객관식 and 듣고 맞히기.
  final ChoiceMaker choiceMaker;
  final StudyCalendar calendar;

  /// The learner's options. [RecordMode.perPlaylist] is not built yet:
  /// study keeps one shared record per word whatever is stored.
  final StudyPreferences preferences;

  /// Whose record [scope]'s cards are. The one place a per-playlist record
  /// would start: today every scope uses [CardScope.shared].
  CardScope cardScopeFor(StudyScope scope) => CardScope.shared;

  Future<StudySummary> summary({
    StudyScope scope = const AllWords(),
    StudyMode mode = StudyMode.meaning,
  }) async {
    final now = clock.now();
    final cardScope = cardScopeFor(scope);
    final words = await _wordsOf(scope);
    final ids = {for (final w in words) w.id};
    final asked = {for (final w in await _askedIn(mode, words)) w.id};
    final shown = {
      for (final w in words)
        if (!w.isHidden && asked.contains(w.id)) w.id,
    };
    final cards = await reviews.cards(
      wordIds: ids,
      scope: cardScope,
      mode: mode,
    );
    final todayLogs = await reviews.logs(
      since: calendar.startOfStudyDay(now),
      scope: cardScope,
      mode: mode,
    );
    final hiddenCount = words.where((w) => w.isHidden).length;
    return StudySummary(
      dueCount: cards.values
          .where((c) => shown.contains(c.wordId) && c.isDue(now))
          .length,
      newCount: shown.where((id) => !cards.containsKey(id)).length,
      aheadCount: cards.values
          .where((c) => shown.contains(c.wordId) && !c.isDue(now))
          .length,
      // Presses made before a word was hidden still happened today.
      knownToday: todayLogs
          .where((l) => l.answer == Answer.known && ids.contains(l.wordId))
          .length,
      wordCount: words.length,
      hiddenCount: hiddenCount,
    );
  }

  Future<List<Word>> _wordsOf(StudyScope scope) => switch (scope) {
    AllWords() => library.words(),
    PlaylistOnly(:final playlistId) => library.words(playlistId: playlistId),
  };

  /// The words of [words] that [mode] can ask: every word for 뜻 맞히기, a
  /// word with a meaning for 일본어 떠올리기, a word a four-option question
  /// can be made for (out of the whole library) for 객관식 and 듣고 맞히기.
  Future<List<Word>> _askedIn(StudyMode mode, List<Word> words) async =>
      switch (mode) {
        StudyMode.meaning => words,
        StudyMode.recall => [
          for (final w in words)
            if (meaningGlosses(w.meaning).isNotEmpty) w,
        ],
        StudyMode.listening ||
        StudyMode.choice => _askable(words, await library.words()),
      };

  List<Word> _askable(List<Word> words, List<Word> pool) {
    final ids = choiceMaker.askable(words, pool);
    return [
      for (final w in words)
        if (ids.contains(w.id)) w,
    ];
  }

  Future<StudySession> startSession({
    StudyScope scope = const AllWords(),
    StudyMode mode = StudyMode.meaning,
    int? goal,
  }) => _startWith(builder.build, scope, mode, goal);

  /// 더 학습하기: a session of cards whose review time has not come yet
  /// (`SessionBuilder.buildMore`).
  Future<StudySession> startMoreSession({
    StudyScope scope = const AllWords(),
    StudyMode mode = StudyMode.meaning,
    int? goal,
  }) => _startWith(builder.buildMore, scope, mode, goal);

  /// The modes that can be studied now: 뜻 맞히기 and 일본어 떠올리기 always,
  /// 객관식 when the library holds four words whose meanings stand apart, and
  /// 듣고 맞히기 when, besides, the words can be read aloud.
  Future<Set<StudyMode>> availableModes({required bool speechAvailable}) async {
    final canAsk = choiceMaker.canAsk(await library.words());
    return {
      StudyMode.meaning,
      StudyMode.recall,
      if (canAsk && speechAvailable) StudyMode.listening,
      if (canAsk) StudyMode.choice,
    };
  }

  /// The multiple-choice question of [session]'s current card; null in the
  /// other modes, when the session is finished, or when no question can be
  /// made. The same presentation always gets the same question.
  MultipleChoice? questionFor(StudySession session) {
    final item = session.current;
    if (item == null || !session.mode.isMultipleChoice) return null;
    return choiceMaker.make(
      answer: item.word,
      pool: session.choicePool,
      seed: choiceSeed(
        sessionStart: session.startedAt,
        wordId: item.word.id,
        retries: item.retries,
      ),
    );
  }

  /// Every mode's cards of [wordIds] (null: of every word), by mode.
  Future<Map<StudyMode, Map<String, ReviewCard>>> cardsByMode({
    Iterable<String>? wordIds,
  }) async {
    final ids = wordIds?.toList();
    return Map.unmodifiable({
      for (final mode in StudyMode.values)
        mode: await reviews.cards(wordIds: ids, mode: mode),
    });
  }

  Future<StudySession> _startWith(
    StudySession Function({
      required List<Word> words,
      required Map<String, ReviewCard> cards,
      required DateTime now,
      required int goal,
    })
    build,
    StudyScope scope,
    StudyMode mode,
    int? goal,
  ) async {
    final cardScope = cardScopeFor(scope);
    final scoped = await _wordsOf(scope);
    final pool = mode.isMultipleChoice ? await library.words() : <Word>[];
    final words = switch (mode) {
      StudyMode.listening || StudyMode.choice => _askable(scoped, pool),
      _ => await _askedIn(mode, scoped),
    };
    final cards = await reviews.cards(
      wordIds: words.map((w) => w.id),
      scope: cardScope,
      mode: mode,
    );
    final session = build(
      words: words,
      cards: cards,
      now: clock.now(),
      goal: goal ?? settings.dailyGoal,
    );
    return StudySession(
      queue: session.queue,
      total: session.total,
      startedAt: session.startedAt,
      mode: mode,
      cardScope: cardScope,
      choicePool: List.unmodifiable(pool),
    );
  }

  /// 처음부터 다시 학습: removes the cards of [wordIds] in every mode so they
  /// are new words again, and returns the removed cards (for
  /// [restoreCards]). Hidden words stay hidden; the press log is kept.
  Future<List<ReviewCard>> resetWords(
    Iterable<String> wordIds, {
    StudyScope scope = const AllWords(),
  }) {
    final ids = wordIds.toList();
    final cardScope = cardScopeFor(scope);
    return reviews.transaction(
      () async => List.unmodifiable([
        for (final mode in StudyMode.values)
          ...await reviews.deleteCards(ids, scope: cardScope, mode: mode),
      ]),
    );
  }

  /// Undoes [resetWords]: puts [cards] back, except for words that got a new
  /// card meanwhile.
  Future<void> restoreCards(List<ReviewCard> cards) =>
      reviews.transaction(() async {
        for (final card in cards) {
          final now = await reviews.card(
            card.wordId,
            scope: card.scope,
            mode: card.mode,
          );
          if (now == null) {
            await reviews.saveCard(card);
          }
        }
      });

  /// Removes every card (every scope and mode): all words are new again. Hidden words,
  /// playlists and the press log stay. Returns how many cards were removed.
  Future<int> resetAll() => reviews.transaction(reviews.deleteAllCards);

  /// Applies [answer] to the current card, stores the new card and the log
  /// in one transaction, and returns the next session state. Both go to the
  /// record of the session's scope and mode.
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
    final scope = session.cardScope;
    final mode = session.mode;
    // The scheduler knows levels and times only: the card is put in the
    // session's record here.
    ReviewCard inRecord(ReviewCard card) =>
        card.copyWith(scope: scope, mode: mode);
    switch (answer) {
      case Answer.known:
        // A card brought forward and known at once keeps its level and its
        // next review; only the press is logged.
        final kept = _keptOnKnown(item);
        final card =
            kept ??
            inRecord(
              scheduler.known(
                wordId: wordId,
                before: item.before,
                retries: item.retries,
                now: now,
              ),
            );
        if (kept == null) await reviews.saveCard(card);
        await reviews.addLog(
          ReviewLog(
            wordId: wordId,
            answer: answer,
            at: now,
            levelBefore: item.before?.level ?? 0,
            levelAfter: card.level,
            retriesInSession: item.retries,
            scope: scope,
            mode: mode,
          ),
        );
        return session.afterKnown(at: now);
      case Answer.retry:
        final card = inRecord(
          scheduler.retry(
            wordId: wordId,
            current: await reviews.card(wordId, scope: scope, mode: mode),
            now: now,
          ),
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
            scope: scope,
            mode: mode,
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

  /// Interval for the 알고있음 button of [item]: for a card brought forward
  /// that 알고있음 would keep, the time left until its review.
  Duration previewKnown(SessionItem item) {
    if (_keptOnKnown(item) case final kept?) {
      final left = kept.dueAt.difference(clock.now());
      return left.isNegative ? Duration.zero : left;
    }
    return scheduler.previewKnown(before: item.before, retries: item.retries);
  }

  /// The card 알고있음 leaves as it is: one brought forward (더 학습하기) and
  /// not retried in this session. After a 다시 학습 the card is due, so the
  /// usual rule applies.
  static ReviewCard? _keptOnKnown(SessionItem item) =>
      item.ahead && item.retries == 0 ? item.before : null;
}
