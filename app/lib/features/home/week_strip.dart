import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/home/home_week.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori_core/shiori_core.dart';

/// This week, Monday first: a short ink stub under each day studied and
/// today as an ink disc. Left out while it loads or when it cannot be read
/// (it only adds context to the day sheet).
class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(studyWeekProvider, (_, next) {
      if (next case AsyncError(:final error, :final stackTrace)) {
        debugPrint('study week: $error\n$stackTrace');
      }
    });
    final week = ref.watch(studyWeekProvider);
    final value = week.value;
    if (week.hasError || value == null) return const SizedBox.shrink();

    final cells = [for (final d in value.days) _DayCell(day: d)];
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At large text sizes the week takes two even rows (월–목, 금–일)
          // instead of shrinking or scrolling sideways.
          if (isLargeText(context))
            Column(
              spacing: Space.md,
              children: [
                for (final row in [cells.sublist(0, 4), cells.sublist(4)])
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(
                          child: i < row.length
                              ? row[i]
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
              ],
            )
          else
            Row(children: [for (final c in cells) Expanded(child: c)]),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final WeekDay day;

  /// What VoiceOver reads. Today's date is the day sheet's label, so the
  /// strip says only 오늘 there.
  String get _label {
    final when = day.isToday ? '오늘' : dateHeading(day.date);
    return day.studied ? '$when, 학습함' : when;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disc = math.max(
      _minDisc,
      MediaQuery.textScalerOf(context).scale(_numberSize) * _discPerText,
    );
    final numberColor = day.isToday ? t.bg : (day.isFuture ? t.text3 : t.text);
    return Semantics(
      container: true,
      label: _label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayLetter(day.date),
              style: TextStyle(
                color: t.text2,
                fontSize: TypeScale.small,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: disc,
              height: disc,
              alignment: Alignment.center,
              decoration: day.isToday
                  ? BoxDecoration(color: t.text, shape: BoxShape.circle)
                  : null,
              child: Text(
                '${day.date.day}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: numberColor,
                  fontSize: _numberSize,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: _stubWidth,
              height: _stubHeight,
              child: day.studied
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.text,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

const double _numberSize = 17;
const double _minDisc = 34;

/// The disc keeps room around the number as the text grows.
const double _discPerText = 1.7;
const double _stubWidth = 14;
const double _stubHeight = 3;
