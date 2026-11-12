import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/home/today_plan.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/sheet.dart';

/// 홈's head: today's page of a tear-off calendar (日めくり). The date is
/// the heading; [body] holds today's numbers as memo rows (or what to do
/// first, or a load failure); the bottom edge is a dashed tear line.
class DaySheet extends StatelessWidget {
  const DaySheet({
    super.key,
    required this.today,
    required this.body,
    this.known,
  });

  /// The study day shown.
  final DateTime today;

  final Widget body;

  /// 오늘 n개 외움, beside the date (under it at large text sizes).
  final Widget? known;

  @override
  Widget build(BuildContext context) {
    final large = isLargeText(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '${dateHeading(today)}, 오늘',
      child: SheetFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (large || known == null)
              _DateHead(today: today)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _DateHead(today: today)),
                  const SizedBox(width: Space.sm),
                  ?known,
                ],
              ),
            if (large && known != null) ...[
              const SizedBox(height: Space.sm),
              ?known,
            ],
            const SizedBox(height: 14),
            body,
          ],
        ),
      ),
    );
  }
}

/// The big day number with the month stacked above the weekday beside it.
/// Read once, as the sheet's label.
class _DateHead extends StatelessWidget {
  const _DateHead({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: Space.lg,
        runSpacing: Space.xs,
        children: [
          // The numeral is the page itself: it grows with the text size
          // only so far, the words beside it keep growing.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: _dayMaxScale,
            child: Text(
              '${today.day}',
              style: TextStyle(
                color: t.text,
                fontSize: 96,
                height: 0.92,
                fontWeight: FontWeight.w800,
                letterSpacing: -3.8,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${today.month}월',
                  style: TextStyle(
                    color: t.text2,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  weekdayName(today),
                  style: TextStyle(
                    color: t.text,
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const double _dayMaxScale = 1.4;

/// Today's numbers as memo rows (label left, value right, ruled between),
/// and how they add up to today's session.
class SheetMemo extends StatelessWidget {
  const SheetMemo({super.key, required this.plan, required this.shuffle});

  final TodayPlan plan;

  /// 카드 순서 섞기 is on (said in the line under the rows).
  final bool shuffle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final line = plan.line(shuffle: shuffle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetMemoList(
          rows: [
            SheetMemoRow(label: '복습할 단어', value: '${plan.due}', unit: '개'),
            SheetMemoRow(
              label: '새 단어',
              value: '${plan.freshToday}',
              unit: '개${plan.freshOutOf ?? ''}',
              last: true,
            ),
          ],
        ),
        if (line != null) ...[
          const SizedBox(height: 2),
          Text(
            line,
            style: TextStyle(color: t.text2, fontSize: 15, height: 1.35),
          ),
        ],
      ],
    );
  }
}

/// What the sheet says when there is nothing to study today.
class SheetNothing extends StatelessWidget {
  const SheetNothing({super.key, required this.noWords});

  /// No word at all yet (the bar below offers 첫 페이지 등록하기).
  final bool noWords;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          noWords ? '먼저 페이지를 등록해 주세요' : '지금은 복습할 단어가 없어요',
          style: context.text.titleMedium?.copyWith(color: t.text),
        ),
        if (!noWords) ...[
          const SizedBox(height: Space.xs),
          Text(
            '복습할 때가 되면 숫자가 올라와요',
            style: context.text.bodyMedium?.copyWith(color: t.text2),
          ),
        ],
      ],
    );
  }
}

/// 오늘 n개 외움 and, small under it, the mode it was counted in.
class KnownToday extends StatelessWidget {
  const KnownToday({super.key, required this.count, this.modeName});

  final int count;

  /// Null while the mode in use loads (no guess).
  final String? modeName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final large = isLargeText(context);
    return Column(
      crossAxisAlignment: large
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '오늘 $count개 외움',
          style: TextStyle(
            color: t.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (modeName case final name?)
          Text(
            name,
            key: const ValueKey('known-today-mode'),
            style: context.text.bodySmall?.copyWith(fontSize: 11),
          ),
      ],
    );
  }
}
