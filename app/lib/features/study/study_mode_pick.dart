import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori_core/shiori_core.dart';

/// Why [mode] cannot be picked now, or null when it can ([available] is
/// what [availableModesProvider] says).
String? studyModeBlocker(
  WidgetRef ref,
  StudyMode mode,
  Set<StudyMode> available,
) => available.contains(mode)
    ? null
    : StudyModeLabels.unavailable(
        mode,
        speechAvailable: ref.watch(speechProvider).isAvailable,
      );

/// Picks [mode] as the way of studying (홈's menu, 재생목록's chips): it is
/// remembered, or, when it cannot be studied now, a snack bar says why and
/// nothing changes.
Future<void> pickStudyMode(
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
