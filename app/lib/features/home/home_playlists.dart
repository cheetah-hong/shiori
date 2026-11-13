import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/decks/decks_screen.dart';
import 'package:shiori/features/home/home_load_error.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 홈's 재생목록: a heading with 편집, then one list row per playlist in the
/// learner's order (or what to do first, or a load failure).
class HomePlaylists extends ConsumerWidget {
  const HomePlaylists({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverMainAxisGroup(
        slivers: [
          const SliverToBoxAdapter(child: _Heading()),
          switch (playlists) {
            AsyncValue(hasError: true) => SliverToBoxAdapter(
              child: HomeLoadError(
                message: '재생목록을 불러오지 못했어요',
                onRetry: () => retryStorage(ref),
              ),
            ),
            AsyncData(value: final items) when items.isEmpty =>
              const SliverToBoxAdapter(child: _EmptyShelf()),
            AsyncData(value: final items) => SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _PlaylistRow(item: items[i]),
            ),
            _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
          },
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) => SectionLabel(
    '재생목록',
    trailing: TextButton(
      onPressed: () => pushScreen<void>(context, const PlaylistsScreen()),
      child: const Text('편집'),
    ),
  );
}

/// A list row: name, word count, chevron; opens the playlist.
class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.item});

  final PlaylistStats item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () => pushScreen<void>(
            context,
            PlaylistScreen(playlistId: item.playlist.id),
          ),
          child: RuledRow(
            child: Row(
              children: [
                Expanded(
                  // The count goes under the name when both do not fit.
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Space.sm,
                    children: [
                      Text(
                        item.playlist.name,
                        style: TextStyle(
                          color: t.text,
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          '단어 ${item.shownCount}개',
                          if (item.hiddenCount > 0)
                            HideLabels.hiddenCount(item.hiddenCount),
                        ].join(' · '),
                        style: TextStyle(
                          color: t.text2,
                          fontSize: TypeScale.body2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.xs),
                Icon(CupertinoIcons.chevron_forward, color: t.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// No playlist yet: one ruled row that says what fills it. The bar below
/// offers 첫 페이지 등록하기; the row offers the built-in decks.
class _EmptyShelf extends ConsumerWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyNote(
    title: '페이지를 등록하고 재생목록에 단어를 모아 보세요',
    body: '사진 속 일본어 단어와 읽기·품사·뜻, 예문을 모아요.',
    // Only in a build with the decks.
    action: ref.watch(builtinDecksProvider).value == null
        ? null
        : TextButton(
            onPressed: () => pushScreen<void>(context, const DecksScreen()),
            child: const Text('기본 단어장 둘러보기'),
          ),
  );
}
