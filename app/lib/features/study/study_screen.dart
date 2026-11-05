import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_controller.dart';
import 'package:shiori/features/study/word_card.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori_core/shiori_core.dart';

/// 학습: one card at a time. 다시 학습 sends it to the back, 알고있음 schedules it.
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key, this.textbookId});

  final String? textbookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyControllerProvider(textbookId));
    return Scaffold(
      body: SafeArea(
        child: switch (state) {
          AsyncData(value: final s) when s.total == 0 =>
            const _NothingToStudy(),
          AsyncData(value: final s) when s.isFinished => _SessionDone(
            session: s,
          ),
          AsyncData(value: final s) => _Session(
            session: s,
            textbookId: textbookId,
          ),
          AsyncError(:final error) => _Failure(
            message: '$error',
            onRetry: () => ref.invalidate(studyControllerProvider(textbookId)),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Session extends ConsumerWidget {
  const _Session({required this.session, required this.textbookId});

  final StudySession session;
  final String? textbookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final item = session.current;
    if (item == null) return const SizedBox.shrink();
    final controller = ref.read(studyControllerProvider(textbookId).notifier);
    final speech = ref.watch(speechProvider);
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
              Expanded(child: Text('오늘 학습', style: context.text.titleMedium)),
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
              child: WordCard(
                // A new key per presentation resets what was revealed.
                key: ValueKey(
                  '${item.word.id}#${session.knownCount}#${session.retryCount}',
                ),
                item: item,
                maxLevel: ref.watch(reviewSchedulerProvider).maxLevel,
                onSpeak: speech.isAvailable
                    ? () => speech.speak(item.word.headword)
                    : null,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
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
                    onPressed: () => controller.answer(Answer.retry),
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
                    onPressed: () => controller.answer(Answer.known),
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
  const _SessionDone({required this.session});

  final StudySession session;

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
  const _NothingToStudy();

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
