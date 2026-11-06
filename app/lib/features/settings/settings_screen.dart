import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 설정: the study options. Only the defaults are built (one shared record
/// per word; 전체 + one playlist at a time); the other choices are listed as
/// 준비 중 so the learner sees where the app is going, and cannot be picked.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
            _Choice(
              title: '재생목록마다 따로',
              selected: value.recordMode == RecordMode.perPlaylist,
            ),
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
            _Choice(
              title: '항상 재생목록 하나씩',
              selected: value.scopeMode == StudyScopeMode.playlistOnly,
            ),
          ],
        ),
        AsyncError(:final error) => Center(
          child: Text('설정을 불러오지 못했어요: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// One choice of a group, read as a radio button. Without [onTap] it is not
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
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: enabled ? t.ink : t.ink3,
          ),
          title: Text(title),
          subtitle: Text(enabled ? subtitle ?? '' : '준비 중'),
          onTap: onTap,
        ),
      ),
    );
  }
}
