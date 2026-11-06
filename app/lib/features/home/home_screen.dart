import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori/features/capture/capture_screen.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori/features/study/study_scope_sheet.dart';
import 'package:shiori/features/study/study_screen.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 홈: today's reviews and new words (전체), and the playlists.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final now = ref.watch(clockProvider).now();
    final summary = ref.watch(homeSummaryProvider);
    final playlists = ref.watch(playlistsProvider);
    final goal = ref.watch(studySettingsProvider).dailyGoal;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.lg,
                Space.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateHeading(now), style: context.text.bodySmall),
                          Semantics(
                            header: true,
                            child: Text(
                              '오늘',
                              style: context.text.headlineLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (summary.value case final s? when s.knownToday > 0)
                      Pill(
                        '오늘 ${s.knownToday}개 외움',
                        background: t.sheet,
                        foreground: t.pen,
                        icon: Icons.local_fire_department,
                      ),
                    IconButton(
                      tooltip: '설정',
                      icon: Icon(Icons.settings_outlined, color: t.ink2),
                      onPressed: () =>
                          pushScreen<void>(context, const SettingsScreen()),
                    ),
                    IconButton(
                      tooltip: '정보',
                      icon: Icon(Icons.info_outline, color: t.ink2),
                      onPressed: () =>
                          pushScreen<void>(context, const AboutScreen()),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.lg,
                Space.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                // Riverpod retries a failed provider; while it does, the
                // state is "loading" but still carries the error.
                child: switch (summary) {
                  AsyncValue(hasError: true) => _SummaryError(
                    onRetry: () => retryStorage(ref),
                  ),
                  AsyncData(:final value) => _TodayCard(
                    summary: value,
                    goal: goal,
                    canPick: playlists.value?.isNotEmpty ?? false,
                  ),
                  _ => const SizedBox(height: 168),
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverToBoxAdapter(
                child: SectionLabel(
                  '재생목록',
                  trailing: TextButton(
                    onPressed: () =>
                        pushScreen<void>(context, const PlaylistsScreen()),
                    child: const Text('편집'),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                120,
              ),
              sliver: switch (playlists) {
                AsyncValue(hasError: true) => SliverToBoxAdapter(
                  child: _SummaryError(
                    message: '재생목록을 불러오지 못했어요',
                    onRetry: () => retryStorage(ref),
                  ),
                ),
                AsyncData(value: final items) when items.isEmpty =>
                  const SliverToBoxAdapter(child: _EmptyShelf()),
                AsyncData(value: final items) => SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) =>
                      _PlaylistTile(item: items[i], index: i),
                ),
                _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pushScreen<void>(context, const CaptureScreen()),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('페이지 등록'),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.summary,
    required this.goal,
    required this.canPick,
  });

  final StudySummary? summary;
  final int goal;

  /// There are playlists to study one of (재생목록 골라 학습).
  final bool canPick;

  Future<void> _pick(BuildContext context) async {
    final scope = await showStudyScopeSheet(context);
    if (scope != null && context.mounted) {
      await pushScreen<void>(context, StudyScreen(scope: scope));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = summary;
    final due = s?.dueCount ?? 0;
    final fresh = s?.newCount ?? 0;
    final cards = (due + fresh) < goal ? due + fresh : goal;
    final canStudy = cards > 0;
    final numberStyle = TextStyle(
      color: t.sheet,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: -1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelStyle = TextStyle(
      color: t.sheet.withValues(alpha: 0.78),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.xl,
        Space.xl,
        Space.lg,
      ),
      decoration: BoxDecoration(
        color: t.ink,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: [
          BoxShadow(
            color: t.ink.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 16),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: '복습할 단어 $due개',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$due', style: numberStyle),
                        const SizedBox(height: 6),
                        Text('복습할 단어', style: labelStyle),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: '새 단어 $fresh개',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$fresh', style: numberStyle),
                        const SizedBox(height: 6),
                        Text('새 단어', style: labelStyle),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PressScale(
            enabled: canStudy,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.marker,
                  foregroundColor: t.markerInk,
                  disabledBackgroundColor: t.sheet.withValues(alpha: 0.12),
                  disabledForegroundColor: t.sheet.withValues(alpha: 0.6),
                ),
                onPressed: canStudy
                    ? () => pushScreen<void>(context, const StudyScreen())
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  canStudy
                      ? '오늘 학습 시작 · $cards장'
                      : (s?.wordCount == 0
                            ? '먼저 페이지를 등록해 주세요'
                            : '지금은 복습할 단어가 없어요'),
                ),
              ),
            ),
          ),
          if (canPick) ...[
            const SizedBox(height: Space.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.sheet,
                  side: BorderSide(color: t.sheet.withValues(alpha: 0.4)),
                ),
                onPressed: () => _pick(context),
                icon: const Icon(Icons.queue_music_outlined),
                label: const Text('재생목록 골라 학습'),
              ),
            ),
          ],
          if (canStudy) ...[
            const SizedBox(height: Space.sm),
            Text(
              '모든 재생목록에서 복습할 단어를 먼저, 남은 자리는 새 단어로 채워요',
              style: labelStyle.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.item, required this.index});

  final PlaylistStats item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = item.playlist.name;
    return PressScale(
      child: Material(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.tile),
          onTap: () => pushScreen<void>(
            context,
            PlaylistScreen(playlistId: item.playlist.id),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              children: [
                BookSpine(
                  label: name.characters.firstOrNull ?? '?',
                  index: index,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: context.text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '단어 ${item.shownCount}개',
                          if (item.hiddenCount > 0)
                            HideLabels.hiddenCount(item.hiddenCount),
                        ].join(' · '),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: t.ink3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.paper3, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: context.text.titleLarge,
              children: [
                const TextSpan(text: '페이지를 찍어 단어를\n'),
                TextSpan(
                  text: '재생목록',
                  style: TextStyle(
                    background: Paint()..color = t.marker,
                    color: t.markerInk,
                  ),
                ),
                const TextSpan(text: '에 모아요'),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Text('페이지를 등록하고 재생목록에 단어를 모아 보세요', style: context.text.titleSmall),
          const SizedBox(height: Space.sm),
          Text(
            '사진 속 일본어 단어와 읽기·품사·뜻, 예문을 모아요. 확인이 필요한 칸만 빨간 펜으로 표시해 드려요.',
            style: context.text.bodyMedium?.copyWith(
              color: t.ink2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of zeros when the summary could not be loaded, so a storage
/// failure never looks like "nothing to review".
class _SummaryError extends StatelessWidget {
  const _SummaryError({
    required this.onRetry,
    this.message = '오늘 학습할 단어를 불러오지 못했어요',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        color: t.riskBg,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: t.risk),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: t.risk, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
        ],
      ),
    );
  }
}
