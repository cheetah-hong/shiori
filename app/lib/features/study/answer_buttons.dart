import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori_core/shiori_core.dart';

/// 다시 학습 and 알고있음 (with the next review time). Side by side, or one
/// above the other with [large] text.
class AnswerButtons extends StatelessWidget {
  const AnswerButtons({
    super.key,
    required this.large,
    required this.preview,
    required this.onAnswer,
  });

  final bool large;
  final String preview;
  final void Function(Answer answer) onAnswer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = buttonShape;
    final retry = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: t.surfaceStrong,
          foregroundColor: t.text,
          shape: shape,
        ),
        onPressed: () => onAnswer(Answer.retry),
        icon: const Icon(Icons.undo_rounded, size: 20),
        label: const Text('다시 학습', textAlign: TextAlign.center),
      ),
    );
    final known = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: FilledButton(
        style: FilledButton.styleFrom(shape: shape),
        onPressed: () => onAnswer(Answer.known),
        child: Semantics(
          label: '알고있음, 다음 복습 $preview',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('알고있음', textAlign: TextAlign.center),
                  Text(
                    preview,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.onAccent,
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
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          known,
          const SizedBox(height: Space.sm),
          retry,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: retry),
          const SizedBox(width: Space.md),
          Expanded(flex: 6, child: known),
        ],
      ),
    );
  }
}
