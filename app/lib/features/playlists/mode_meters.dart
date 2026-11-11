import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// A word's memory level in each way of studying: four small meters, each
/// under its letter (뜻·일·듣·객), read out as one line.
class ModeMeters extends StatelessWidget {
  const ModeMeters({super.key, required this.levels, required this.max});

  /// Level per mode; a mode left out is a new word there.
  final Map<StudyMode, int> levels;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    String said(StudyMode mode) {
      final level = levels[mode] ?? 0;
      return '${StudyModeLabels.name(mode)} '
          '${level == 0 ? '새 단어' : '$level단계'}';
    }

    return Semantics(
      container: true,
      label: '기억 단계: ${StudyMode.values.map(said).join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in StudyMode.values)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      StudyModeLabels.letter(mode),
                      style: TextStyle(
                        color: t.ink3,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    MemoryMeter(
                      level: levels[mode] ?? 0,
                      max: max,
                      compact: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
