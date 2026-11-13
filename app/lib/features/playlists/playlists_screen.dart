import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/decks/decks_screen.dart';
import 'package:shiori/features/words/word_search_screen.dart';
import 'package:shiori/shared/action_sheet.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/playlists/playlist_names.dart';
import 'package:shiori/shared/ruled.dart';
import 'package:shiori/shared/states.dart';
import 'package:shiori_core/shiori_core.dart';

/// 재생목록 편집: make, rename, delete and order the playlists (drag a row
/// by its handle, or move it from its menu).
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final library = ref.read(libraryServiceProvider);
    final revision = ref.read(dataRevisionProvider.notifier);
    final List<String> taken;
    try {
      taken = [
        for (final s in await ref.read(playlistsProvider.future))
          s.playlist.name,
      ];
    } on Exception catch (e, stack) {
      debugPrint('playlists for a new one: $e\n$stack');
      messenger.showSnackBar(
        const SnackBar(content: Text('재생목록을 불러오지 못했어요. 다시 시도해 주세요')),
      );
      return;
    }
    if (!context.mounted) return;
    final name = await showPlaylistNameDialog(
      context,
      title: '새 재생목록',
      action: '만들기',
      taken: taken,
    );
    if (name == null) return;
    try {
      await library.createPlaylist(name);
      revision.bump();
    } on LibraryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Exception catch (e, stack) {
      debugPrint('create playlist failed: $e\n$stack');
      messenger.showSnackBar(
        const SnackBar(content: Text('만들지 못했어요. 다시 시도해 주세요')),
      );
    }
  }

  Future<void> _reorder(
    WidgetRef ref,
    ScaffoldMessengerState messenger,
    List<PlaylistStats> lists,
    int from,
    int to,
  ) async {
    final ids = [for (final s in lists) s.playlist.id];
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    try {
      await ref.read(libraryServiceProvider).reorderPlaylists(ids);
      ref.read(dataRevisionProvider.notifier).bump();
    } on Exception catch (e, stack) {
      debugPrint('reorder failed: $e\n$stack');
      messenger.showSnackBar(
        const SnackBar(content: Text('순서를 바꾸지 못했어요. 다시 시도해 주세요')),
      );
    }
  }

  Widget _failed(WidgetRef ref, Object error) {
    debugPrint('playlists failed to load: $error');
    return LoadFailure(
      message: '재생목록을 불러오지 못했어요',
      onRetry: () => retryStorage(ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('재생목록 편집'),
        actions: [
          const WordSearchButton(),
          IconButton(
            tooltip: '기본 단어장',
            icon: const Icon(CupertinoIcons.book),
            onPressed: () => pushScreen<void>(context, const DecksScreen()),
          ),
          IconButton(
            tooltip: '새 재생목록',
            icon: const Icon(CupertinoIcons.plus),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: switch (state) {
        AsyncValue(:final value?, hasError: false) => _List(
          lists: value,
          onReorder: (from, to) =>
              _reorder(ref, ScaffoldMessenger.of(context), value, from, to),
          onCreate: () => _create(context, ref),
        ),
        AsyncError(:final error) => _failed(ref, error),
        _ => const Loading(),
      },
    );
  }
}

enum _RowAction { up, down, rename, delete }

class _List extends ConsumerWidget {
  const _List({
    required this.lists,
    required this.onReorder,
    required this.onCreate,
  });

  final List<PlaylistStats> lists;

  /// 새 재생목록 (offered when there is none).
  final VoidCallback onCreate;

  /// Moves the row at the first index to the second (after removing it).
  final Future<void> Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    if (lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: EmptyNote(
          title: '재생목록이 없어요',
          body: '페이지를 등록하면서 만들거나, 여기서 먼저 만들 수 있어요.',
          action: TextButton(onPressed: onCreate, child: const Text('새 재생목록')),
        ),
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.xl,
      ),
      // A row being dragged lifts as paper does: a fill, no shadow.
      proxyDecorator: (child, _, _) => Material(color: t.surface, child: child),
      itemCount: lists.length,
      onReorder: (from, to) => onReorder(from, to > from ? to - 1 : to),
      itemBuilder: (context, i) {
        final s = lists[i];
        final name = s.playlist.name;
        return RuledRow(
          key: ValueKey('edit-${s.playlist.id}'),
          ruleAbove: i == 0,
          padding: EdgeInsets.zero,
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
                      name,
                      style: TextStyle(
                        color: t.text,
                        fontSize: TypeScale.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '단어 ${s.shownCount}개',
                      style: TextStyle(
                        color: t.text2,
                        fontSize: TypeScale.body2,
                      ),
                    ),
                  ],
                ),
              ),
              _RowMenu(
                name: name,
                index: i,
                last: i == lists.length - 1,
                onReorder: onReorder,
                stats: s,
              ),
              ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Icon(CupertinoIcons.line_horizontal_3, color: t.text3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A row's menu: move it up or down, rename, delete.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({
    required this.name,
    required this.index,
    required this.last,
    required this.onReorder,
    required this.stats,
  });

  final String name;
  final int index;
  final bool last;
  final Future<void> Function(int from, int to) onReorder;
  final PlaylistStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = index;
    final s = stats;
    return MoreButton<_RowAction>(
      tooltip: '$name 메뉴',
      choices: () => [
        if (i > 0) const SheetChoice(label: '위로 옮기기', value: _RowAction.up),
        if (!last) const SheetChoice(label: '아래로 옮기기', value: _RowAction.down),
        const SheetChoice(label: '이름 바꾸기', value: _RowAction.rename),
        const SheetChoice(
          label: '삭제',
          value: _RowAction.delete,
          destructive: true,
        ),
      ],
      onSelected: (action) async {
        switch (action) {
          case _RowAction.up:
            await onReorder(i, i - 1);
          case _RowAction.down:
            await onReorder(i, i + 1);
          case _RowAction.rename:
            await renamePlaylist(context, ref, s.playlist);
          case _RowAction.delete:
            await deletePlaylist(
              context,
              ref,
              s.playlist,
              wordCount: s.wordCount,
            );
        }
      },
    );
  }
}
