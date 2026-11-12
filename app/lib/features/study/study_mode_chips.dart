import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/features/study/study_mode_pick.dart';
import 'package:shiori_core/shiori_core.dart';

/// The four ways of studying as chips (재생목록; 홈 folds them into one row).
/// Picking one remembers it; one that cannot be studied now says why.
class StudyModeChips extends ConsumerWidget {
  const StudyModeChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // None picked until the mode in use is known (no guess while it loads).
    final current = ref.watch(studyModeProvider).value;
    final available =
        ref.watch(availableModesProvider).value ??
        const {StudyMode.meaning, StudyMode.recall};
    // Wrapped, not scrolled: every mode stays in sight on a narrow phone.
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (final mode in StudyMode.values)
          MergeSemantics(
            child: Semantics(
              // Why it cannot be picked now, read with the chip.
              hint: studyModeBlocker(ref, mode, available),
              child: ChoiceChip(
                key: ValueKey('mode-${mode.name}'),
                label: Text(StudyModeLabels.name(mode)),
                selected: mode == current,
                showCheckmark: false,
                selectedColor: t.accentTint,
                backgroundColor: t.bg,
                side: BorderSide(
                  color: mode == current ? t.accent : t.outline,
                  width: mode == current ? 1.5 : 1,
                ),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: mode == current
                      ? t.accentText
                      : (available.contains(mode) ? t.text : t.text3),
                ),
                onSelected: (_) => pickStudyMode(
                  context,
                  ref,
                  mode,
                  available: available.contains(mode),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
