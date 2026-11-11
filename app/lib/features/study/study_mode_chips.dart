import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori_core/shiori_core.dart';

/// The four ways of studying as chips (홈 and 재생목록 show the same choice).
/// Picking one remembers it; one that cannot be studied now says why.
class StudyModeChips extends ConsumerWidget {
  const StudyModeChips({super.key, this.onDark = false});

  /// On the dark 오늘 card.
  final bool onDark;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    StudyMode mode, {
    required bool available,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!available) {
      final speech = ref.read(speechProvider).isAvailable;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              StudyModeLabels.unavailable(mode, speechAvailable: speech),
            ),
          ),
        );
      return;
    }
    try {
      await saveStudyMode(ref, mode);
    } on Exception catch (e, stack) {
      debugPrint('saving the study mode failed: $e\n$stack');
      messenger.showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // None picked until the mode in use is known (no guess while it loads).
    final current = ref.watch(studyModeProvider).value;
    final available =
        ref.watch(availableModesProvider).value ??
        const {StudyMode.meaning, StudyMode.recall};
    final ink = onDark ? t.sheet : t.ink;
    // Wrapped, not scrolled: every mode stays in sight on a narrow phone.
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (final mode in StudyMode.values)
          ChoiceChip(
            key: ValueKey('mode-${mode.name}'),
            label: Text(StudyModeLabels.name(mode)),
            selected: mode == current,
            showCheckmark: false,
            selectedColor: onDark ? t.marker : t.ink,
            backgroundColor: onDark ? t.ink : t.sheet,
            side: BorderSide(color: ink.withValues(alpha: 0.3)),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: mode == current
                  ? (onDark ? t.markerInk : t.sheet)
                  : ink.withValues(alpha: available.contains(mode) ? 1 : 0.45),
            ),
            onSelected: (_) =>
                _pick(context, ref, mode, available: available.contains(mode)),
          ),
      ],
    );
  }
}
