import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/backup/backup_section.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/shared/adaptive_dialog.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 설정: the study options. 학습 세션 holds the daily goal (how many cards
/// 홈 studies at a time) and 카드 순서 섞기. Of 학습 기록 and 학습 범위 only
/// the defaults are built (one shared record per word; 전체 + one playlist
/// at a time); the other choices are one quiet line at the end of their
/// section (준비 중), so the learner sees where the app is going without a
/// row that cannot be picked. 학습 기록 also holds 모든
/// 단어 처음부터 다시 학습 (asked first). 백업, last, makes and restores
/// backup files.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _failed(WidgetRef ref, Object error) {
    debugPrint('settings failed to load: $error');
    return LoadFailure(
      message: '설정을 불러오지 못했어요',
      onRetry: () => retryStorage(ref),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    StudyPreferences preferences,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(studyPreferencesRepositoryProvider).save(preferences);
      ref.invalidate(studyPreferencesProvider);
    } on Exception catch (e, stack) {
      debugPrint('settings save failed: $e\n$stack');
      messenger.showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: switch (state) {
        AsyncValue(:final value?, hasError: false) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          children: [
            const SectionLabel('학습 세션'),
            _DailyGoalPicker(
              goal: value.dailyGoal,
              onPick: (goal) =>
                  _save(context, ref, value.copyWith(dailyGoal: goal)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('카드 순서 섞기'),
              subtitle: const Text('복습과 새 단어를 섞어서 보여요'),
              value: value.shuffle,
              onChanged: (on) =>
                  _save(context, ref, value.copyWith(shuffle: on)),
            ),
            const Divider(),
            const SectionLabel('학습 기록'),
            _Choice(
              title: '재생목록끼리 공유',
              subtitle: '같은 단어는 어느 목록에서 공부해도 기록이 하나예요',
              selected: value.recordMode == RecordMode.shared,
              onTap: () => _save(
                context,
                ref,
                value.copyWith(recordMode: RecordMode.shared),
              ),
            ),
            // Not built yet: a row only if it is somehow the stored value
            // (so the screen still shows what is on).
            if (value.recordMode == RecordMode.perPlaylist)
              const _Choice(title: '재생목록마다 따로', selected: true),
            const _Upcoming('재생목록마다 따로 기록하기는 준비 중이에요.'),
            const Divider(),
            const _ResetAll(),
            const SectionLabel('학습 범위'),
            _Choice(
              title: '전체 복습 + 재생목록 골라 학습',
              subtitle: '오늘 학습은 모든 목록에서, 목록 하나만 고를 수도 있어요',
              selected: value.scopeMode == StudyScopeMode.allOrPlaylist,
              onTap: () => _save(
                context,
                ref,
                value.copyWith(scopeMode: StudyScopeMode.allOrPlaylist),
              ),
            ),
            if (value.scopeMode == StudyScopeMode.playlistOnly)
              const _Choice(title: '항상 재생목록 하나씩', selected: true),
            const _Upcoming('항상 재생목록 하나씩 학습하기는 준비 중이에요.'),
            const Divider(),
            const BackupSection(),
          ],
        ),
        AsyncError(:final error) => _failed(ref, error),
        _ => const Loading(),
      },
    );
  }
}

/// 하루 목표: 10 · 20 · 30 · 50 · 전부, one of them picked.
class _DailyGoalPicker extends StatelessWidget {
  const _DailyGoalPicker({required this.goal, required this.onPick});

  final DailyGoal goal;
  final ValueChanged<DailyGoal> onPick;

  static String _label(DailyGoal goal) => switch (goal.cards) {
    final n? => '$n',
    null => '전부',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('하루 목표', style: context.text.titleMedium),
        const SizedBox(height: 2),
        Text(
          '홈 「오늘 학습」에서 한 번에 학습하는 카드 수예요. '
          '재생목록에서 학습하면 그 목록을 모두 학습해요',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: Space.sm),
        // From about the AX1 text size five segments in a row break their
        // labels apart: separate chips that wrap instead.
        if (isLargeText(context))
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final g in DailyGoal.values)
                ChoiceChip(
                  label: Text(_label(g)),
                  selected: g == goal,
                  onSelected: (_) => onPick(g),
                ),
            ],
          )
        else
          CupertinoSlidingSegmentedControl<DailyGoal>(
            groupValue: goal,
            backgroundColor: context.tokens.surfaceStrong,
            thumbColor: context.tokens.bg,
            onValueChanged: (picked) {
              if (picked != null) onPick(picked);
            },
            children: {
              for (final g in DailyGoal.values)
                g: ConstrainedBox(
                  // 44 pt to press.
                  constraints: const BoxConstraints(minHeight: _segmentHeight),
                  child: Center(
                    child: Text(
                      _label(g),
                      style: TextStyle(
                        color: context.tokens.text,
                        fontSize: 15,
                        fontWeight: g == goal
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            },
          ),
      ],
    ),
  );
}

const double _segmentHeight = 44;

/// A choice not built yet, folded into one small line at the end of its
/// section.
class _Upcoming extends StatelessWidget {
  const _Upcoming(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xs, bottom: Space.md),
    child: Text(
      text,
      style: TextStyle(color: context.tokens.text3, fontSize: 13),
    ),
  );
}

/// One choice of a group as an iOS check row (the chosen one has an accent
/// check on the right), read as a radio button. Without [onTap] it is not
/// built yet: shown as 준비 중 and disabled.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.selected,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        enabled: enabled,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: enabled,
          title: Text(title),
          subtitle: Text(enabled ? subtitle ?? '' : '준비 중'),
          trailing: selected
              ? Icon(Icons.check, color: enabled ? t.accentText : t.text3)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// 모든 단어 처음부터 다시 학습: after a confirmation, every card of every
/// mode goes (every word is new again); the press log, hidden words and
/// playlists stay. Off while no word has been studied in any mode.
class _ResetAll extends ConsumerWidget {
  const _ResetAll();

  Future<void> _reset(BuildContext context, WidgetRef ref, int count) async {
    final messenger = ScaffoldMessenger.of(context);
    final study = ref.read(studyServiceProvider);
    final revision = ref.read(dataRevisionProvider.notifier);
    final sure = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text(RestudyLabels.resetAllQuestion),
        content: Text(RestudyLabels.resetAllDetail(count)),
        actions: [
          adaptiveDialogAction(
            context,
            label: '취소',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          adaptiveDialogAction(
            context,
            label: RestudyLabels.resetAllConfirm,
            destructive: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      // Every mode's cards go; the message counts words, not cards.
      await study.resetAll();
      revision.bump();
      messenger.showSnackBar(
        SnackBar(content: Text(RestudyLabels.allReset(count))),
      );
    } on Exception catch (e, stack) {
      debugPrint('reset all failed: $e\n$stack');
      messenger.showSnackBar(
        const SnackBar(content: Text(RestudyLabels.resetAllFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Words studied in any mode: each counts once.
    final count = {
      for (final cards
          in ref.watch(cardsByModeProvider).value?.values ??
              const <Map<String, ReviewCard>>[])
        ...cards.keys,
    }.length;
    final enabled = count > 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: const Icon(Icons.restart_alt),
      title: const Text(RestudyLabels.resetAll),
      subtitle: Text(
        enabled ? RestudyLabels.resetAllHint : RestudyLabels.nothingLearned,
      ),
      onTap: enabled ? () => _reset(context, ref, count) : null,
    );
  }
}
