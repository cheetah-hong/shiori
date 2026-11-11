import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori_core/shiori_core.dart';

/// 「무엇을 학습할까요?」: 전체 or one playlist, each with what is due and new
/// today. One with nothing to study cannot be picked. Null when closed.
Future<StudyScope?> showStudyScopeSheet(BuildContext context) =>
    showModalBottomSheet<StudyScope>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ScopeSheet(),
    );

class _ScopeSheet extends ConsumerWidget {
  const _ScopeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(playlistsProvider).value ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('무엇을 학습할까요?', style: context.text.titleLarge),
            Text(
              '방식: ${StudyModeLabels.name(ref.watch(studyModeProvider).value ?? StudyMode.meaning)}',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Space.md),
            _ScopeRow(
              key: const ValueKey('scope-all'),
              title: '전체',
              scope: const AllWords(),
              summary: ref.watch(homeSummaryProvider),
            ),
            for (final s in lists)
              _ScopeRow(
                key: ValueKey('scope-${s.playlist.id}'),
                title: s.playlist.name,
                scope: PlaylistOnly(s.playlist.id),
                summary: ref.watch(playlistSummaryProvider(s.playlist.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    super.key,
    required this.title,
    required this.scope,
    required this.summary,
  });

  final String title;
  final StudyScope scope;
  final AsyncValue<StudySummary> summary;

  @override
  Widget build(BuildContext context) {
    final s = summary.value;
    final cards = s == null ? 0 : s.dueCount + s.newCount;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        scope is AllWords ? Icons.all_inclusive : Icons.queue_music_outlined,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(switch (summary) {
        AsyncValue(hasError: true) => '불러오지 못했어요',
        AsyncData() when cards == 0 => '오늘 할 것 없음',
        AsyncData() => '복습 ${s!.dueCount} · 새 단어 ${s.newCount}',
        _ => '',
      }),
      enabled: cards > 0,
      onTap: cards == 0 ? null : () => Navigator.of(context).pop(scope),
    );
  }
}
