import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/voicevox_speech.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/features/study/recall_card.dart';
import 'package:shiori/features/study/choice_card.dart';
import 'package:shiori/features/study/study_controller.dart';
import 'package:shiori/features/study/word_card.dart';
import 'package:shiori/features/study/word_speech.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
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

  void _answer(Answer answer) => unawaited(_store(answer));

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
    setState(() {
      _picked = picked;
      _writing = true;
    });
    final stored = await _store(
      picked.option.id == picked.question.answer.id
          ? Answer.known
          : Answer.retry,
    );
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

  @override
  Widget build(BuildContext context) {
    if (_mode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            Expanded(
              child: switch (state) {
                // The last pick's result shows before 오늘 학습 끝.
                AsyncData(value: final s) when picked != null => _Session(
                  session: s,
                  request: request,
                  onAnswer: _answer,
                  onHide: _hide,
                  picked: picked,
                  onPick: _pick,
                  onNext: _writing ? null : _next,
                ),
                AsyncData(value: final s) when s.total == 0 => _NothingToStudy(
                  onMore: onMore,
                ),
                AsyncData(value: final s) when s.isFinished => _SessionDone(
                  session: s,
                  onMore: onMore,
                ),
                AsyncData(value: final s) => _Session(
                  session: s,
                  request: request,
                  onAnswer: _answer,
                  onHide: _hide,
                  onPick: _pick,
                  onNext: _next,
                ),
                AsyncError(:final error) => _Failure(
                  message: '$error',
                  onRetry: () {
                    // A pick that failed is not shown on the new session.
                    setState(() => _picked = null);
                    ref.invalidate(studyControllerProvider(request));
                  },
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
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
            color: t.paper2,
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Row(
            children: [
              Icon(
                failed ? Icons.error_outline : Icons.visibility_off_outlined,
                size: 18,
                color: failed ? t.risk : t.ink2,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  message,
                  style: context.text.bodyMedium?.copyWith(
                    color: failed ? t.risk : t.ink,
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
    required this.onHide,
    required this.onPick,
    required this.onNext,
    this.picked,
  });

  final StudySession session;
  final StudyRequest request;
  final ValueChanged<Answer> onAnswer;
  final VoidCallback onHide;
  final ValueChanged<_Picked> onPick;

  /// Null while the pick's answer is being written.
  final VoidCallback? onNext;

  /// The pick on screen (객관식, 듣고 맞히기); its card stays until 다음.
  final _Picked? picked;

  /// The card of [mode] for [item].
  Widget _card(
    WidgetRef ref, {
    required SessionItem item,
    required StudyMode mode,
    required String cardKey,
    required Future<void> Function()? onSpeakWord,
    required Future<void> Function()? onSpeakExample,
    required CardExample? filledExample,
    required PitchInfo? pitch,
    required Future<int?> Function()? estimatePitch,
  }) {
    final key = ValueKey(cardKey);
    final question = mode.isMultipleChoice
        ? picked?.question ??
              ref
                  .read(studyControllerProvider(request).notifier)
                  .questionFor(session)
        : null;
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
        question: question,
        listening: mode == StudyMode.listening,
        picked: picked?.option.id,
        onPick: (option) => onPick((
          item: item,
          question: question,
          option: option,
          cardKey: cardKey,
        )),
        onNext: onNext,
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
    final cardKey =
        picked?.cardKey ??
        '${item.word.id}#${session.knownCount}#${session.retryCount}';
    final controller = ref.read(studyControllerProvider(request).notifier);
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

    return Column(
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
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(_title(request), style: context.text.titleMedium),
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
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.sm,
          ),
          child: _ProgressBar(value: session.progress),
        ),
        Expanded(
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
              child: _card(
                ref,
                item: item,
                mode: mode,
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
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: t.ink2,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onHide,
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: Semantics(
                  label: HideLabels.buttonSemantics,
                  child: const ExcludeSemantics(child: Text(HideLabels.button)),
                ),
              ),
            ),
          ),
        if (mode.isMultipleChoice)
          const SizedBox(height: Space.lg)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              Space.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: t.paper2,
                        foregroundColor: t.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => onAnswer(Answer.retry),
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      label: const Text('다시 학습'),
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 60,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => onAnswer(Answer.known),
                      child: Semantics(
                        label: '알고있음, 다음 복습 $preview',
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('알고있음'),
                              Text(
                                preview,
                                style: TextStyle(
                                  color: t.marker,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 「오늘 학습」 or 「더 학습하기」, with the mode's name unless it is 뜻 맞히기.
String _title(StudyRequest request) {
  final what = request.more ? RestudyLabels.more : '오늘 학습';
  return request.mode == StudyMode.meaning
      ? what
      : StudyModeLabels.header(what, request.mode);
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.chip),
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: t.paper2,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: Motion.of(context, const Duration(milliseconds: 600)),
            curve: Motion.easeOut,
            builder: (_, v, _) => Transform.scale(
              scaleX: v,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: t.ink, child: const SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionDone extends ConsumerWidget {
  const _SessionDone({required this.session, this.onMore});

  final StudySession session;

  /// 더 학습하기; null when no card can be brought forward.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final elapsed =
        session.elapsed ??
        ref.read(clockProvider).now().difference(session.startedAt);
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: t.marker, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 44, color: t.markerInk),
          ),
          const SizedBox(height: Space.lg),
          Semantics(
            header: true,
            child: Text('오늘 학습 끝', style: context.text.headlineSmall),
          ),
          const SizedBox(height: Space.xl),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
            childAspectRatio: 2.3,
            children: [
              _DoneStat(value: elapsedLabel(elapsed), label: '소요 시간'),
              _DoneStat(value: '${session.knownNewCount}개', label: '새로 외운 단어'),
              _DoneStat(value: '${session.knownReviewCount}개', label: '복습한 단어'),
              _DoneStat(
                value: '${session.retryCount}번',
                label: '다시 학습',
                color: t.pen,
              ),
            ],
          ),
          const Spacer(flex: 2),
          if (onMore case final more?) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: more,
                icon: const Icon(Icons.replay_rounded),
                label: const Text(RestudyLabels.more),
              ),
            ),
            const SizedBox(height: Space.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneStat extends StatelessWidget {
  const _DoneStat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: context.text.titleLarge?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _NothingToStudy extends StatelessWidget {
  const _NothingToStudy({this.onMore});

  /// 더 학습하기; null when no card can be brought forward.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('지금 학습할 카드가 없어요', style: context.text.titleLarge),
          const SizedBox(height: Space.sm),
          Text('복습할 때가 되면 홈에 숫자가 올라와요', style: context.text.bodyMedium),
          const SizedBox(height: Space.xl),
          if (onMore case final more?) ...[
            FilledButton.icon(
              onPressed: more,
              icon: const Icon(Icons.replay_rounded),
              label: const Text(RestudyLabels.more),
            ),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('돌아가기'),
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('돌아가기'),
            ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('학습을 이어 가지 못했어요', style: context.text.titleLarge),
          const SizedBox(height: Space.sm),
          Text(
            message,
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xl),
          FilledButton(onPressed: onRetry, child: const Text('다시 시작')),
        ],
      ),
    );
  }
}
