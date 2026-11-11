import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/card_parts.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori_core/shiori_core.dart';

/// 객관식 and 듣고 맞히기: one meaning out of four. 객관식 shows the word and
/// its example; 듣고 맞히기 shows nothing of the word, plays it once by
/// itself and has 다시 듣기. Once picked ([picked] set) the card says whether
/// it was right, marks the answer, shows the word, its reading and the
/// example's translation, and offers 다음.
class ChoiceCard extends StatefulWidget {
  const ChoiceCard({
    super.key,
    required this.item,
    required this.question,
    required this.listening,
    required this.onPick,
    required this.onNext,
    this.picked,
    this.onPlayWord,
    this.onSpeakExample,
    this.pitch,
  });

  final SessionItem item;
  final MultipleChoice question;

  /// 듣고 맞히기: the word is heard, not seen, until a pick.
  final bool listening;

  /// The id of the option picked; null until then.
  final String? picked;
  final ValueChanged<Word> onPick;

  /// Null (the button off) while the pick is being stored.
  final VoidCallback? onNext;

  /// Plays the word; null without speech. 듣고 맞히기 plays it once when the
  /// card appears.
  final Future<void> Function()? onPlayWord;
  final Future<void> Function()? onSpeakExample;
  final PitchInfo? pitch;

  @override
  State<ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<ChoiceCard> with CardSpeech {
  bool _wordLoading = false;
  bool _exampleLoading = false;

  @override
  void initState() {
    super.initState();
    final play = widget.onPlayWord;
    if (widget.listening && widget.picked == null && play != null) {
      // The one sound this mode plays by itself: right after the card shows.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playWord(play);
      });
    }
  }

  Future<void> _playWord(Future<void> Function() play) =>
      speakWith(play, (on) => _wordLoading = on);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = widget.item.word;
    final answered = widget.picked != null;
    final right = widget.picked == widget.question.answer.id;
    final showWord = answered || !widget.listening;
    final example = w.example;
    final playExample = widget.onSpeakExample;
    final playWord = widget.onPlayWord;
    return CardFrame(
      item: widget.item,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.listening && !answered && playWord != null)
                    IconButton.filledTonal(
                      tooltip: StudyModeLabels.replay,
                      iconSize: 40,
                      onPressed: _wordLoading
                          ? null
                          : () => _playWord(playWord),
                      icon: _wordLoading
                          ? const SizedBox.square(
                              dimension: 40,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(Icons.volume_up_rounded),
                    ),
                  if (showWord) ...[
                    if (answered) ...[
                      Text(
                        readingsLabel(w.readings),
                        style: JpType.gothic(17, t.ink3, height: 1.3),
                      ),
                      if (widget.pitch case final pitch?) ...[
                        const SizedBox(height: Space.xs),
                        PitchLine(info: pitch),
                      ],
                    ],
                    Text(
                      w.headword,
                      style: JpType.print(
                        headwordSize(w.headword) * 0.8,
                        t.ink,
                        weight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (example != null) ...[
                      const SizedBox(height: Space.sm),
                      ExampleSentence(
                        sentence: example.ja,
                        focus: w.headword,
                        style: JpType.gothic(14, t.ink2, height: 1.6),
                        onSpeak: playExample == null || _exampleLoading
                            ? null
                            : () => speakWith(
                                playExample,
                                (on) => _exampleLoading = on,
                              ),
                      ),
                      if (answered)
                        Text(
                          example.ko,
                          style: context.text.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ],
                  const SizedBox(height: Space.lg),
                  for (final option in widget.question.options)
                    _Option(
                      key: ValueKey('option-${option.id}'),
                      meaning: option.meaning,
                      isAnswer: option.id == widget.question.answer.id,
                      isPicked: option.id == widget.picked,
                      answered: answered,
                      onTap: () => widget.onPick(option),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (answered)
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  right ? Icons.check_circle : Icons.cancel,
                  color: right ? t.ok : t.risk,
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    right ? StudyModeLabels.right : StudyModeLabels.wrong,
                    style: context.text.titleMedium?.copyWith(
                      color: right ? t.ok : t.risk,
                    ),
                  ),
                ),
                if (playWord != null) ...[
                  SpeakButton(
                    tooltip: '발음 듣기',
                    loading: _wordLoading,
                    onPressed: () => _playWord(playWord),
                  ),
                  const SizedBox(width: Space.xs),
                ],
                FilledButton(
                  onPressed: widget.onNext,
                  child: const Text(StudyModeLabels.next),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One meaning to pick; after the pick the answer is marked 정답 and a wrong
/// pick shows as such.
class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.meaning,
    required this.isAnswer,
    required this.isPicked,
    required this.answered,
    required this.onTap,
  });

  final String meaning;
  final bool isAnswer;
  final bool isPicked;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Color? edge = !answered
        ? null
        : isAnswer
        ? t.ok
        : isPicked
        ? t.risk
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(
              color: edge ?? t.paper3,
              width: edge == null ? 1 : 2,
            ),
            foregroundColor: t.ink,
            disabledForegroundColor: t.ink,
          ),
          onPressed: answered ? null : onTap,
          child: Row(
            children: [
              Expanded(child: Text(meaning, textAlign: TextAlign.left)),
              if (answered && isAnswer)
                Text(
                  StudyModeLabels.answerMark,
                  style: TextStyle(color: t.ok, fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
