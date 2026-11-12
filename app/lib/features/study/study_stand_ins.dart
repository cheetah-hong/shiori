import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/restudy_labels.dart';

// What the study screen shows when there is no card to show.

/// Nothing to study now: why, with 더 학습하기 when some card can be
/// brought forward.
class NothingToStudy extends StatelessWidget {
  const NothingToStudy({super.key, this.onMore});

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

/// The session could not go on: what failed and 다시 시작.
class StudyFailure extends StatelessWidget {
  const StudyFailure({super.key, required this.message, required this.onRetry});

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
