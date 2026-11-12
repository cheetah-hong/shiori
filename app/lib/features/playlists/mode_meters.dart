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

/// A word's memory level in every way of studying, in a bottom sheet: each
/// mode by its full name, its meter and its level in words. [current] is
/// the way in use (the one the playlist row shows).
Future<void> showModeLevels(
  BuildContext context, {
  required Word word,
  required Map<StudyMode, int> levels,
  required int max,
  required StudyMode current,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _LevelsSheet(word: word, levels: levels, max: max, current: current),
);

class _LevelsSheet extends StatelessWidget {
  const _LevelsSheet({
    required this.word,
    required this.levels,
    required this.max,
    required this.current,
  });

  final Word word;
  final Map<StudyMode, int> levels;
  final int max;
  final StudyMode current;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        // Clear of the home indicator.
        Space.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JpText(word.headword, style: JpType.print(28, t.text)),
            const SizedBox(height: Space.xs),
            Text('학습 방식마다 기억 단계', style: context.text.bodySmall),
            const SizedBox(height: Space.md),
            for (final (i, mode) in StudyMode.values.indexed)
              _LevelRow(
                mode: mode,
                level: levels[mode] ?? 0,
                max: max,
                isCurrent: mode == current,
                first: i == 0,
              ),
          ],
        ),
      ),
    );
  }
}

/// One way of studying: its name (지금 for the one in use), the meter and
/// the level in words, read as one line.
class _LevelRow extends StatelessWidget {
  const _LevelRow({
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(color: t.text, fontSize: 17),
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
                        fontSize: 15,
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
