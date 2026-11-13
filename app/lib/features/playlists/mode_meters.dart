import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// [mode] and a word's level in it, as said aloud and in the sheet:
/// 「뜻 맞히기 2단계」, 「객관식 새 단어」.
String modeLevelSaid(StudyMode mode, int level) =>
    '${StudyModeLabels.name(mode)} ${levelSaid(level)}';

/// 「2단계」, or 「새 단어」 for a word not studied yet.
String levelSaid(int level) => level == 0 ? '새 단어' : '$level단계';

/// One way of studying in a word's sheet: its name (지금 for the one in
/// use), the meter and the level in words, read as one line.
class ModeLevelRow extends StatelessWidget {
  const ModeLevelRow({
    super.key,
    required this.mode,
    required this.level,
    required this.max,
    required this.isCurrent,
    required this.first,
  });

  final StudyMode mode;
  final int level;
  final int max;
  final bool isCurrent;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final longTerm = level >= max;
    return RuledRow(
      ruleAbove: first,
      child: Semantics(
        container: true,
        label: [
          modeLevelSaid(mode, level),
          if (longTerm) '장기 기억',
          if (isCurrent) '지금 학습 방식',
        ].join(', '),
        child: ExcludeSemantics(
          // Full width, so the level sits at the right end when it fits.
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.sm,
              runSpacing: Space.xs,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: StudyModeLabels.name(mode)),
                      if (isCurrent)
                        TextSpan(
                          text: '  지금',
                          style: TextStyle(
                            color: t.accentText,
                            fontSize: TypeScale.small,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(color: t.text, fontSize: TypeScale.body),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MemoryMeter(level: level, max: max),
                    const SizedBox(width: Space.sm),
                    Text(
                      longTerm
                          ? '${levelSaid(level)} · 장기 기억'
                          : levelSaid(level),
                      style: TextStyle(
                        color: level == 0 ? t.text3 : t.text2,
                        fontSize: TypeScale.body2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
