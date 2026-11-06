import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/playlists/playlist_actions.dart';
import 'package:shiori/features/playlists/playlist_names.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('재생목록 편집'),
        actions: [
          IconButton(
            tooltip: '새 재생목록',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: switch (state) {
        AsyncValue(:final value?, hasError: false) => _List(
          lists: value,
          onReorder: (from, to) =>
              _reorder(ref, ScaffoldMessenger.of(context), value, from, to),
        ),
        AsyncError(:final error) => Center(
          child: Text('재생목록을 불러오지 못했어요: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

enum _RowAction { up, down, rename, delete }

class _List extends ConsumerWidget {
  const _List({required this.lists, required this.onReorder});

  final List<PlaylistStats> lists;

  /// Moves the row at the first index to the second (after removing it).
  final Future<void> Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    if (lists.isEmpty) {
      return Center(
        child: Text(
          '재생목록이 없어요',
          style: context.text.bodyMedium?.copyWith(color: t.ink2),
        ),
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      itemCount: lists.length,
      onReorder: (from, to) => onReorder(from, to > from ? to - 1 : to),
      itemBuilder: (context, i) {
        final s = lists[i];
        final name = s.playlist.name;
        return ListTile(
          key: ValueKey('edit-${s.playlist.id}'),
          leading: ReorderableDragStartListener(
            index: i,
            child: Icon(Icons.drag_handle, color: t.ink3),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('단어 ${s.shownCount}개'),
          trailing: PopupMenuButton<_RowAction>(
            tooltip: '$name 메뉴',
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
            itemBuilder: (_) => [
              if (i > 0)
                const PopupMenuItem(
                  value: _RowAction.up,
                  child: Text('위로 옮기기'),
                ),
              if (i < lists.length - 1)
                const PopupMenuItem(
                  value: _RowAction.down,
                  child: Text('아래로 옮기기'),
                ),
              const PopupMenuItem(
                value: _RowAction.rename,
                child: Text('이름 바꾸기'),
              ),
              const PopupMenuItem(value: _RowAction.delete, child: Text('삭제')),
            ],
          ),
        );
      },
    );
  }
}
