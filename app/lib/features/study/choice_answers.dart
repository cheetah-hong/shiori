import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/shared/bottom_action_bar.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori_core/shiori_core.dart';

/// 객관식 and 듣고 맞히기: the four meanings to pick from, in the fixed
/// place at the bottom where the other modes have 다시 학습 / 알고있음 —
/// four ruled rows. Once picked ([picked] set) the rows say which was right
/// (정답) and which was the wrong pick (내 선택), and under them the result
/// (맞았어요 / 틀렸어요) with 다음.
class ChoiceAnswers extends StatelessWidget {
  const ChoiceAnswers({
    super.key,
    required this.question,
    required this.large,
    required this.onPick,
    required this.onNext,
    this.picked,
  });

  final MultipleChoice question;

  /// Large text: the result goes over 다음 instead of beside it.
  final bool large;

  /// The id of the option picked; null until then.
  final String? picked;
  final ValueChanged<Word> onPick;

  /// Null (the button off) while the pick is being stored.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    final answerId = question.answer.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, option) in question.options.indexed)
          _OptionRow(
            key: ValueKey('option-${option.id}'),
            meaning: option.meaning,
            isAnswer: option.id == answerId,
            isPicked: option.id == picked,
            answered: answered,
            first: i == 0,
            onTap: () => onPick(option),
          ),
        if (answered) ...[
          const SizedBox(height: Space.md),
          _Result(right: picked == answerId, large: large, onNext: onNext),
        ],
      ],
    );
  }
}

/// One meaning to pick: a ruled row, a faint accent wash while pressed.
/// After the pick the answer says 정답 and a wrong pick 내 선택, in words
/// and not only in color.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.meaning,
    required this.isAnswer,
    required this.isPicked,
    required this.answered,
    required this.first,
    required this.onTap,
  });

  final String meaning;
  final bool isAnswer;
  final bool isPicked;
  final bool answered;

  /// Also ruled on top.
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rule = BorderSide(color: t.line);
    // The room around the words grows with them, so large text never
    // touches a rule.
    final scaler = MediaQuery.textScalerOf(context);
    final mark = switch ((answered, isAnswer, isPicked)) {
      (true, true, _) => (StudyModeLabels.answerMark, t.ok),
      (true, false, true) => (StudyModeLabels.pickMark, t.risk),
      _ => null,
    };
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: !answered,
        selected: answered && isPicked,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: answered ? null : onTap,
            highlightColor: t.accentTint,
            splashColor: t.accentTint,
            child: Container(
              constraints: const BoxConstraints(minHeight: ruledRowHeight),
              padding: EdgeInsets.symmetric(
                horizontal: math.max(Space.md, scaler.scale(Space.sm)),
                vertical: math.max(Space.sm, scaler.scale(Space.sm)),
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: first ? rule : BorderSide.none,
                  bottom: rule,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      meaning,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 17,
                        fontWeight: isAnswer && answered
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (mark case (final label, final color)) ...[
                    const SizedBox(width: Space.sm),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 맞았어요 / 틀렸어요 and 다음: side by side, or one over the other with
/// large text.
class _Result extends StatelessWidget {
  const _Result({
    required this.right,
    required this.large,
    required this.onNext,
  });

  final bool right;
  final bool large;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = right ? t.ok : t.risk;
    final said = Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(right ? Icons.check_circle : Icons.cancel, color: color),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              right ? StudyModeLabels.right : StudyModeLabels.wrong,
              style: context.text.titleMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    final next = BarPrimaryButton(
      label: StudyModeLabels.next,
      onPressed: onNext,
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          said,
          const SizedBox(height: Space.sm),
          next,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: said),
        const SizedBox(width: Space.md),
        SizedBox(width: _nextWidth, child: next),
      ],
    );
  }
}

const double _nextWidth = 140;
