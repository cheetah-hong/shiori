import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/voicevox_speech.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/reminder_labels.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori/features/study/answer_buttons.dart';
import 'package:shiori/features/study/choice_answers.dart';
import 'package:shiori/features/study/choice_card.dart';
import 'package:shiori/features/study/haptics.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori/features/study/recall_card.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/features/study/session_done.dart';
import 'package:shiori/features/study/session_tear.dart';
import 'package:shiori/features/study/study_controller.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/features/study/study_stand_ins.dart';
import 'package:shiori/features/study/swipe_answer.dart';
import 'package:shiori/features/study/word_card.dart';
import 'package:shiori/features/study/word_speech.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

/// 학습: one card at a time. 다시 학습 sends it to the back, 알고있음 schedules it,
/// 이미 알아요 hides the word (with 되돌리기 right after).
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({
    super.key,
    this.scope = const AllWords(),
    this.more = false,
    this.mode,
  });

  /// What to study: every playlist (전체) or one.
  final StudyScope scope;

  /// 더 학습하기: cards whose review time has not come, instead of today's.
  final bool more;

  /// The way of studying; null: the one in use when the screen opens (it
  /// does not change while the screen is open).
  final StudyMode? mode;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  /// The card hidden last, for 되돌리기. Cleared by the next answer.
  SessionItem? _hidden;

  /// A hide or undo that failed, shown in the same place.
  String? _failure;

  /// The way of studying, once known.
  StudyMode? _mode;

  /// A multiple-choice pick whose result is on screen until 다음 (the answer
  /// is already stored and the session has moved on).
  _Picked? _picked;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    if (_mode != null) return;
    ref
        .read(studyModeProvider.future)
        .then(
          (mode) {
            if (mounted) setState(() => _mode = mode);
          },
          onError: (Object e, StackTrace stack) {
            debugPrint('study mode: $e\n$stack');
            if (mounted) setState(() => _mode = StudyMode.meaning);
          },
        );
  }

  StudyRequest get _request => (
    scope: widget.scope,
    more: widget.more,
    mode: _mode ?? StudyMode.meaning,
  );

  StudyController get _controller =>
      ref.read(studyControllerProvider(_request).notifier);

  /// 더 학습하기: this screen gives way to a session of cards brought forward.
  /// Already one: a new session of them starts here (a new screen would get
  /// the same, finished session, as the old one still holds it).
  void _studyMore() {
    _stopSound();
    if (widget.more) {
      setState(_clearNotice);
      ref.invalidate(studyControllerProvider(_request));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            StudyScreen(scope: widget.scope, more: true, mode: _mode),
      ),
    );
  }

  Future<void> _hide() => _guard(HideLabels.hideFailed, () async {
    _stopSound();
    final item = await _controller.hide();
    if (mounted && item != null) {
      setState(() {
        _hidden = item;
        _failure = null;
      });
    }
  });

  Future<void> _undo(SessionItem item) =>
      _guard(HideLabels.restoreFailed, () async {
        await _controller.unhide(item);
        if (mounted) setState(_clearNotice);
      });

  /// Runs a hide or an undo; a failure leaves the session as it was and
  /// tells the learner instead of ending the session.
  Future<void> _guard(String failure, Future<void> Function() write) async {
    try {
      await write();
    } on Exception catch (e, stack) {
      // A storage block failed (a disk error, say).
      debugPrint('study hide failed: $e\n$stack');
      _failed(failure);
    } on Error catch (e, stack) {
      // A bug in a block: report it like any uncaught error.
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stack, library: 'study'),
      );
      _failed(failure);
    }
  }

  void _clearNotice() {
    _hidden = null;
    _failure = null;
  }

  void _failed(String message) {
    if (mounted) setState(() => _failure = message);
  }

  /// Stops the card's sound when the card is answered or hidden: a sound
  /// still being made for it is then not played over the next card. (Not when
  /// the old card leaves the screen: that comes after the switch animation
  /// and would cut a sound already asked for on the next card.)
  void _stopSound() {
    final speech = ref.read(speechProvider);
    if (!speech.isAvailable) return;
    unawaited(speech.stop().catchError((Object _) {}));
  }

  /// 알고있음 or 다시 학습 from the buttons: one tap, then the answer.
  void _answer(Answer answer) {
    unawaited(ref.read(hapticsProvider).answer());
    unawaited(_store(answer));
  }

  /// The same from a swipe (its threshold already tapped) or a VoiceOver
  /// action on the card shown as [cardKey]; the swipe line is not needed
  /// any more. Whether the card may leave: a card answered meanwhile by a
  /// button has gone already (its swipe is dropped, not given to the next
  /// card); an answer that was not stored brings the card back.
  Future<bool> _swiped(Answer answer, String cardKey) async {
    final session = ref.read(studyControllerProvider(_request)).value;
    final current = session?.current;
    if (session == null ||
        current == null ||
        _cardKeyOf(current, session) != cardKey) {
      return true;
    }
    _hinted();
    return _store(answer);
  }

  /// The swipe line has been seen: a swipe, or a session's end.
  void _hinted() {
    final settings = ref.read(nudgeSettingsProvider).value;
    if (settings == null || settings.swipeHinted) return;
    unawaited(
      ref
          .read(nudgeSettingsProvider.notifier)
          .change((s) => s.copyWith(swipeHinted: true))
          .catchError((Object e) => debugPrint('swipe line not kept: $e')),
    );
  }

  /// 오늘 학습 끝 shows: one tap.
  void _ended() {
    unawaited(ref.read(hapticsProvider).sessionEnd());
    _hinted();
  }

  Future<bool> _store(Answer answer) {
    _stopSound();
    if (_hidden != null || _failure != null) {
      setState(_clearNotice);
    }
    return _controller.answer(answer);
  }

  /// The pick's answer is being written; 다음 waits for it.
  bool _writing = false;

  /// 객관식 and 듣고 맞히기: a pick is stored at once (right = 알고있음, wrong
  /// = 다시 학습); the card and its result stay until 다음. A pick while
  /// another write is on its way is ignored, and one that was not stored
  /// does not stay on screen.
  Future<void> _pick(_Picked picked) async {
    if (_writing || _controller.isBusy) return;
    final right = picked.option.id == picked.question.answer.id;
    final haptics = ref.read(hapticsProvider);
    unawaited(right ? haptics.right() : haptics.wrong());
    setState(() {
      _picked = picked;
      _writing = true;
    });
    final stored = await _store(right ? Answer.known : Answer.retry);
    if (!mounted) return;
    setState(() {
      _writing = false;
      if (!stored) _picked = null;
    });
  }

  void _next() {
    if (_writing) return;
    _stopSound();
    setState(() => _picked = null);
  }

  /// The session, 오늘 학습 끝 (the last card torn off on the way), or
  /// what stands in for them.
  Widget _body(
    AsyncValue<StudySession> state,
    _Picked? picked,
    VoidCallback? onMore,
  ) {
    final request = _request;
    final body = switch (state) {
      // The last pick's result shows before 오늘 학습 끝.
      AsyncData(value: final s) when picked != null => _Session(
        session: s,
        request: request,
        onAnswer: _answer,
        onSwipe: _swiped,
        onHide: _hide,
        picked: picked,
        onPick: _pick,
        onNext: _writing ? null : _next,
      ),
      AsyncData(value: final s) when s.total == 0 => NothingToStudy(
        onMore: onMore,
      ),
      AsyncData(value: final s) when s.isFinished => SessionDone(
        session: s,
        onMore: onMore,
      ),
      AsyncData(value: final s) => _Session(
        session: s,
        request: request,
        onAnswer: _answer,
        onSwipe: _swiped,
        onHide: _hide,
        onPick: _pick,
        onNext: _next,
      ),
      AsyncError(:final error) => StudyFailure(
        message: '$error',
        onRetry: () {
          // A pick that failed is not shown on the new session.
          setState(() => _picked = null);
          ref.invalidate(studyControllerProvider(request));
        },
      ),
      _ => const Loading(),
    };
    return SessionTear(
      live: body is _Session,
      done: body is SessionDone,
      onEnd: _ended,
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == null) {
      return const Scaffold(body: Loading());
    }
    final scope = widget.scope;
    final request = _request;
    final picked = _picked;
    final state = ref.watch(studyControllerProvider(request));
    final canStudyMore =
        (watchStudySummary(ref, scope).value?.aheadCount ?? 0) > 0;
    final onMore = canStudyMore ? _studyMore : null;
    final hidden = _hidden;
    final failure = _failure;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (failure != null)
              _Notice(message: failure, failed: true)
            else if (hidden != null)
              _Notice(
                message: HideLabels.hidden(hidden.word.headword),
                onUndo: () => _undo(hidden),
              ),
            Expanded(child: _body(state, picked, onMore)),
          ],
        ),
      ),
    );
  }
}

/// The line above the session after 이미 알아요: what was hidden and
/// 되돌리기, or why it could not be hidden. It sits above the card, not over
/// the answer buttons.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.onUndo, this.failed = false});

  final String message;
  final VoidCallback? onUndo;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final undo = onUndo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xs,
        Space.gutter,
        0,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Row(
            children: [
              Icon(
                failed
                    ? CupertinoIcons.exclamationmark_circle
                    : CupertinoIcons.eye_slash,
                size: 18,
                color: failed ? t.risk : t.text2,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  message,
                  style: context.text.bodyMedium?.copyWith(
                    color: failed ? t.risk : t.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (undo != null)
                TextButton(onPressed: undo, child: const Text(HideLabels.undo)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A multiple-choice pick: the card it was made on (with its question and
/// the key of its presentation) and the option picked.
typedef _Picked = ({
  SessionItem item,
  MultipleChoice question,
  Word option,
  String cardKey,
});

class _Session extends ConsumerWidget {
  const _Session({
    required this.session,
    required this.request,
    required this.onAnswer,
    required this.onSwipe,
    required this.onHide,
    required this.onPick,
    required this.onNext,
    this.picked,
  });

  final StudySession session;
  final StudyRequest request;
  final ValueChanged<Answer> onAnswer;

  /// An answer from swiping the card (or its VoiceOver actions).
  final Future<bool> Function(Answer answer, String cardKey) onSwipe;
  final VoidCallback onHide;
  final ValueChanged<_Picked> onPick;

  /// Null while the pick's answer is being written.
  final VoidCallback? onNext;

  /// The pick on screen (객관식, 듣고 맞히기); its card stays until 다음.
  final _Picked? picked;

  /// [card], swipeable in the self-graded ways (뜻 맞히기, 일본어
  /// 떠올리기); as it is in 객관식 and 듣고 맞히기.
  Widget _swipeable(
    WidgetRef ref, {
    required String cardKey,
    required StudyMode mode,
    required Widget card,
  }) {
    if (mode.isMultipleChoice) return card;
    return SwipeToAnswer(
      key: ValueKey('swipe-$cardKey'),
      onAnswer: (answer) => onSwipe(answer, cardKey),
      // 알고있음 on the last card left ends the session (and tears it off).
      endsSession: session.queue.length == 1,
      onThreshold: () => unawaited(ref.read(hapticsProvider).answer()),
      child: card,
    );
  }

  /// The card of [mode] for [item].
  Widget _card(
    WidgetRef ref, {
    required SessionItem item,
    required StudyMode mode,
    required MultipleChoice? question,
    required String cardKey,
    required Future<void> Function()? onSpeakWord,
    required Future<void> Function()? onSpeakExample,
    required CardExample? filledExample,
    required PitchInfo? pitch,
    required Future<int?> Function()? estimatePitch,
  }) {
    final key = ValueKey(cardKey);
    return switch (mode) {
      StudyMode.recall => RecallCard(
        key: key,
        item: item,
        onSpeakWord: onSpeakWord,
        onSpeakExample: onSpeakExample,
        pitch: pitch,
      ),
      StudyMode.choice ||
      StudyMode.listening when question != null => ChoiceCard(
        key: key,
        item: item,
        listening: mode == StudyMode.listening,
        picked: picked?.option.id,
        onPlayWord: onSpeakWord,
        onSpeakExample: onSpeakExample,
        pitch: pitch,
      ),
      // 뜻 맞히기, and a question that could not be made (the session leaves
      // such words out, so only if the library changed meanwhile).
      _ => WordCard(
        key: key,
        item: item,
        maxLevel: ref.watch(reviewSchedulerProvider).maxLevel,
        onSpeakWord: onSpeakWord,
        onSpeakExample: onSpeakExample,
        filledExample: filledExample,
        pitch: pitch,
        estimatePitch: estimatePitch,
      ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final item = picked?.item ?? session.current;
    if (item == null) return const SizedBox.shrink();
    final mode = request.mode;
    // A new key per presentation resets what was revealed.
    final cardKey = picked?.cardKey ?? _cardKeyOf(item, session);
    final controller = ref.read(studyControllerProvider(request).notifier);
    // 객관식 and 듣고 맞히기: the card asks, the rows under it answer.
    final question = mode.isMultipleChoice
        ? picked?.question ?? controller.questionFor(session)
        : null;
    final speech = ref.watch(speechProvider);
    // Until the accent table has loaded the card shows it without data; a
    // button pressed meanwhile waits for the table, so the sound keeps the
    // accent the data has.
    final accentsNow =
        ref.watch(accentTableProvider).asData?.value ?? AccentTable.empty;
    final wordSpeech = wordSpeechFor(item.word, accentsNow);
    // A word whose page printed no example shows a sentence of its entry.
    final filled = item.word.example == null
        ? ref.watch(cardExampleProvider(item.word)).value
        : null;
    final exampleSpeech = exampleSpeechFor(
      item.word,
      accentsNow,
      filled: filled,
    );
    Future<AccentTable> accents() async {
      try {
        return await ref.read(accentTableProvider.future);
      } on Object {
        return AccentTable.empty;
      }
    }

    final estimator = switch (speech) {
      final AccentEstimator e => e,
      _ => null,
    };
    final preview = intervalLabel(controller.previewKnown(item));
    final duration = Motion.of(context, Motion.card);
    // From about the AX1 text size the parts around the card would leave it
    // no room: the screen scrolls and the card is as tall as what it holds.
    final large = isLargeText(context);
    // 뜻 맞히기 and 일본어 떠올리기: the card can be swiped; told once.
    final swipeHint =
        !mode.isMultipleChoice &&
        ref.watch(nudgeSettingsProvider).value?.swipeHinted == false;

    return _StudyLayout(
      large: large,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.xs,
            Space.xs,
            Space.gutter,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: '학습 그만하기',
                icon: const Icon(CupertinoIcons.xmark),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: large
                    ? const SizedBox.shrink()
                    : Semantics(
                        header: true,
                        child: KeepWordsText(
                          _title(request),
                          style: context.text.titleMedium,
                        ),
                      ),
              ),
              Semantics(
                label: '${session.total}장 중 ${session.knownCount}장 완료',
                child: ExcludeSemantics(
                  child: Text(
                    '${session.knownCount} / ${session.total}',
                    style: context.text.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (large)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Semantics(
              header: true,
              child: KeepWordsText(
                _title(request),
                style: context.text.titleMedium,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.sm,
          ),
          child: _ProgressBar(value: session.progress),
        ),
        _CardSlot(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: Motion.easeExpo,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _swipeable(
                ref,
                cardKey: cardKey,
                mode: mode,
                card: _card(
                  ref,
                  item: item,
                  mode: mode,
                  question: question,
                  cardKey: cardKey,
                  onSpeakWord: speech.isAvailable
                      ? () async => speech.speak(
                          wordSpeechFor(item.word, await accents()),
                        )
                      : null,
                  onSpeakExample: speech.isAvailable && exampleSpeech != null
                      ? () async => speech.speak(
                          exampleSpeechFor(
                                item.word,
                                await accents(),
                                filled: filled,
                              ) ??
                              exampleSpeech,
                        )
                      : null,
                  filledExample: filled,
                  pitch: pitchInfoFor(wordSpeech),
                  estimatePitch: speech.isAvailable && estimator != null
                      ? () => estimator.estimateAccent(wordSpeech)
                      : null,
                ),
              ),
            ),
          ),
        ),
        if (swipeHint)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: Text(
              ReminderLabels.swipeHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: t.text2),
            ),
          ),
        // 이미 알아요 is a quiet text button apart from the two answers, so it
        // is not taken for 알고있음 (which schedules the next review). Gone
        // while a pick's result is on screen: that card is answered.
        if (picked == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: t.text2,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onHide,
                child: Semantics(
                  label: HideLabels.buttonSemantics,
                  child: const ExcludeSemantics(child: Text(HideLabels.button)),
                ),
              ),
            ),
          ),
        // The answers' fixed place at the bottom, in every mode.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.lg,
          ),
          child: question != null
              ? ChoiceAnswers(
                  key: ValueKey('answers-$cardKey'),
                  question: question,
                  large: large,
                  picked: picked?.option.id,
                  onPick: (option) => onPick((
                    item: item,
                    question: question,
                    option: option,
                    cardKey: cardKey,
                  )),
                  onNext: onNext,
                )
              : AnswerButtons(
                  large: large,
                  preview: preview,
                  onAnswer: onAnswer,
                ),
        ),
      ],
    );
  }
}

/// The card's place: the rest of the screen, or (large text) its own height
/// in a scrolling screen.
class _CardSlot extends StatelessWidget {
  const _CardSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A column whose card slot takes the remaining height, or with [large]
/// text a fixed first row (close, count) over a scrolling rest in which the
/// card is as tall as what it holds.
class _StudyLayout extends StatelessWidget {
  const _StudyLayout({required this.large, required this.children});

  final bool large;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!large) {
      return Column(
        children: [
          for (final c in children)
            c is _CardSlot
                ? Expanded(child: TearCard(child: c))
                : TearFade(child: c),
        ],
      );
    }
    // The first row (close, count) stays; the rest scrolls.
    return Column(
      children: [
        TearFade(child: children.first),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final c in children.skip(1))
                  c is _CardSlot ? TearCard(child: c) : TearFade(child: c),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The head of a session: the way's name (「오늘 학습」 or 「더 학습하기」 for
/// 뜻 맞히기, the plain way).
String _title(StudyRequest request) {
  if (request.mode != StudyMode.meaning) {
    return StudyModeLabels.name(request.mode);
  }
  return request.more ? RestudyLabels.more : '오늘 학습';
}

/// How far the session is: a square-ended 2 pt ink line on a hairline,
/// as a ruled calendar page.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: _progressHeight,
      child: ColoredBox(
        color: t.line,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: Motion.of(context, const Duration(milliseconds: 600)),
          curve: Motion.easeOut,
          builder: (_, v, _) => Transform.scale(
            scaleX: v,
            alignment: Alignment.centerLeft,
            child: ColoredBox(color: t.text, child: const SizedBox.expand()),
          ),
        ),
      ),
    );
  }
}

const double _progressHeight = 2;

/// The key of [item]'s presentation in [session]: a new one per answer, so
/// what was revealed resets.
String _cardKeyOf(SessionItem item, StudySession session) =>
    '${item.word.id}#${session.knownCount}#${session.retryCount}';
