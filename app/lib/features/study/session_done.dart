import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/reminders/reminder_offer.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/sheet.dart';
import 'package:shiori_core/shiori_core.dart';

/// 오늘 학습 끝: today's page with the session's numbers as memo rows,
/// then 더 학습하기 (when some card can be brought forward) and 확인.
class SessionDone extends ConsumerWidget {
  const SessionDone({super.key, required this.session, this.onMore});

  final StudySession session;

  /// 더 학습하기; null when no card can be brought forward.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed =
        session.elapsed ??
        ref.read(clockProvider).now().difference(session.startedAt);
    // Scrolls when the text is large; otherwise the spacers centre the
    // sheet in the space above the buttons.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(Space.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, box.maxHeight - Space.gutter * 2),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Semantics(
                  header: true,
                  child: KeepWordsText(
                    '오늘 학습 끝',
                    style: context.text.headlineSmall,
                  ),
                ),
                const SizedBox(height: Space.md),
                SheetFrame(
                  padding: const EdgeInsets.fromLTRB(14, Space.xs, 14, 0),
                  child: _Numbers(session: session, elapsed: elapsed),
                ),
                const ReminderOffer(),
                const Spacer(),
                if (onMore case final more?) ...[
                  OutlinedButton(
                    onPressed: more,
                    child: const Text(RestudyLabels.more),
                  ),
                  const SizedBox(height: Space.sm),
                ],
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The session's numbers, one memo row each.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.session, required this.elapsed});

  final StudySession session;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SheetMemoRow(label: '소요 시간', value: elapsedLabel(elapsed)),
      SheetMemoRow(
        label: '새로 외운 단어',
        value: '${session.knownNewCount}',
        unit: '개',
      ),
      SheetMemoRow(
        label: '복습한 단어',
        value: '${session.knownReviewCount}',
        unit: '개',
      ),
      SheetMemoRow(
        label: '다시 학습',
        value: '${session.retryCount}',
        unit: '번',
        last: true,
      ),
    ],
  );
}
