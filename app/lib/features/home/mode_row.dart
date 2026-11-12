import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori/features/study/study_mode_pick.dart';
import 'package:shiori/features/study/study_scope_sheet.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori_core/shiori_core.dart';

/// 홈's study options between rules: the way of studying as one pop-up
/// row, and 재생목록 골라 학습 when there are playlists.
class StudyOptions extends StatelessWidget {
  const StudyOptions({super.key, required this.canPick, this.noWords = false});

  /// There are playlists to study one of.
  final bool canPick;

  /// The library has no word yet: why some ways cannot be picked is left
  /// to the menu until there are words.
  final bool noWords;

  Future<void> _pickPlaylist(BuildContext context) async {
    final scope = await showStudyScopeSheet(context);
    if (scope != null && context.mounted) {
      await pushScreen<void>(context, StudyScreen(scope: scope));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rule = BorderSide(color: t.line);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: rule, bottom: rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudyModeRow(showBlockers: !noWords),
            if (canPick)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: rule)),
                child: TextButton.icon(
                  onPressed: () => _pickPlaylist(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(_rowHeight),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.queue_music_outlined),
                  label: const Text('재생목록 골라 학습'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const double _rowHeight = 50;

/// 「학습 방식 · 뜻 맞히기 ↕」: opens a menu of the four ways. A way that
/// cannot be studied now says why, there (and under the row once there are
/// words), and picking it
/// changes nothing.
class StudyModeRow extends ConsumerWidget {
  const StudyModeRow({super.key, this.showBlockers = true});

  /// Why a way cannot be picked, also under the row (always in the menu).
  final bool showBlockers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // No name until the mode in use is known (no guess while it loads).
    final current = ref.watch(studyModeProvider).value;
    final name = current == null ? null : StudyModeLabels.name(current);
    final available = ref.watch(availableModesProvider).value;
    final blockers = {
      for (final mode in StudyMode.values)
        mode: studyModeBlocker(
          ref,
          mode,
          available ?? const {StudyMode.meaning, StudyMode.recall},
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuAnchor(
          // Under the current way on the right, as an iOS pop-up button.
          style: const MenuStyle(alignment: AlignmentDirectional.bottomEnd),
          menuChildren: [
            for (final mode in StudyMode.values)
              _ModeItem(
                mode: mode,
                selected: mode == current,
                blocker: blockers[mode],
                onPressed: () => pickStudyMode(
                  context,
                  ref,
                  mode,
                  available: blockers[mode] == null,
                ),
              ),
          ],
          builder: (context, controller, _) {
            void toggle() =>
                controller.isOpen ? controller.close() : controller.open();
            return Semantics(
              container: true,
              button: true,
              expanded: controller.isOpen,
              label: name == null ? '학습 방식' : '학습 방식, $name',
              excludeSemantics: true,
              onTap: toggle,
              child: InkWell(
                onTap: toggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _rowHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: _ModeRowContent(name: name),
                  ),
                ),
              ),
            );
          },
        ),
        // Only once the modes are known: a guess could name a way that can
        // be picked.
        if (available != null && showBlockers)
          for (final MapEntry(key: mode, value: why) in blockers.entries)
            if (why != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Semantics(
                  container: true,
                  // The reason is part of what is said, not only a hint
                  // (hints can be turned off in VoiceOver).
                  label: '${StudyModeLabels.name(mode)}, $why',
                  hint: why,
                  child: ExcludeSemantics(
                    child: Text(
                      '${StudyModeLabels.name(mode)} — $why',
                      style: TextStyle(color: t.text3, fontSize: 13),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _ModeRowContent extends StatelessWidget {
  const _ModeRowContent({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The current way goes under the label when both do not fit.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.sm,
      children: [
        Text('학습 방식', style: TextStyle(color: t.text, fontSize: 17)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name case final name?)
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    color: t.accentText,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: Space.xs),
            Icon(Icons.unfold_more, size: 20, color: t.accentText),
          ],
        ),
      ],
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.mode,
    required this.selected,
    required this.blocker,
    required this.onPressed,
  });

  final StudyMode mode;
  final bool selected;

  /// Why it cannot be picked now; null when it can.
  final String? blocker;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final why = blocker;
    return Semantics(
      selected: selected,
      child: MenuItemButton(
        onPressed: onPressed,
        trailingIcon: selected
            ? Icon(Icons.check, size: 20, color: t.accentText)
            : null,
        child: Semantics(
          hint: why,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _menuTextWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  StudyModeLabels.name(mode),
                  style: TextStyle(
                    color: why == null ? t.text : t.text3,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (why != null)
                  ExcludeSemantics(
                    child: Text(
                      why,
                      style: TextStyle(
                        color: t.text3,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const double _menuTextWidth = 240;
