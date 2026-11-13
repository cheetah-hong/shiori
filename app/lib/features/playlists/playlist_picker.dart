import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/playlists/playlist_names.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 「어느 재생목록에 추가할까요?」: the learner's playlists, the one last
/// added to first, each with how many of the words it already holds
/// ([preview]), and a new playlist. [exceptPlaylistId] (the playlist the
/// words come from) is left out. Null when the sheet is closed.
Future<AddTarget?> showPlaylistPicker(
  BuildContext context, {
  AddPreview? preview,
  String? exceptPlaylistId,
}) => showModalBottomSheet<AddTarget>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _Picker(preview: preview, except: exceptPlaylistId),
);

/// [lists] the one last added to first; never-used ones after, in their
/// order.
List<PlaylistStats> lastUsedFirst(List<PlaylistStats> lists) {
  final indexed = [...lists.indexed]
    ..sort((a, b) {
      final x = a.$2.lastAddedAt, y = b.$2.lastAddedAt;
      if (x != null && y != null && x != y) return y.compareTo(x);
      if (x != null && y == null) return -1;
      if (x == null && y != null) return 1;
      return a.$1.compareTo(b.$1);
    });
  return [for (final (_, s) in indexed) s];
}

class _Picker extends ConsumerStatefulWidget {
  const _Picker({required this.preview, required this.except});

  final AddPreview? preview;
  final String? except;

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  final _name = TextEditingController();
  bool _creating = false;
  bool _named = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Opens the new-playlist form with 「내 단어장」 unless that is taken.
  void _openForm(List<PlaylistStats> all) {
    final taken = [for (final s in all) s.playlist.name];
    if (!_named) {
      _name.text = playlistNameProblem(defaultPlaylistName, taken) == null
          ? defaultPlaylistName
          : '';
      _named = true;
    }
    _creating = true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(playlistsProvider);
    final all = state.value ?? const <PlaylistStats>[];
    final lists = lastUsedFirst([
      for (final s in all)
        if (s.playlist.id != widget.except) s,
    ]);
    if (state.hasValue && all.isEmpty && !_creating) _openForm(all);
    final taken = [for (final s in all) s.playlist.name];
    final problem = playlistNameProblem(_name.text, taken);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.xl +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('어느 재생목록에 추가할까요?', style: context.text.titleLarge),
            const SizedBox(height: Space.md),
            if (state.hasError)
              Text(
                '재생목록을 불러오지 못했어요',
                style: TextStyle(color: t.risk, fontWeight: FontWeight.w600),
              ),
            if (!_creating)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '새 재생목록',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => setState(() => _openForm(all)),
              )
            else ...[
              Text(
                '새 재생목록',
                style: context.text.labelLarge?.copyWith(color: t.text3),
              ),
              const SizedBox(height: Space.sm),
              TextField(
                controller: _name,
                autofocus: all.isNotEmpty,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '재생목록 이름',
                  errorText: problem == null || problem.isEmpty
                      ? null
                      : problem,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: problem == null && state.hasValue
                    ? () => Navigator.of(
                        context,
                      ).pop(NewPlaylist(_name.text.trim()))
                    : null,
                child: const Text('만들고 추가'),
              ),
              const SizedBox(height: Space.md),
            ],
            for (final s in lists)
              _Row(
                key: ValueKey('pick-${s.playlist.id}'),
                stats: s,
                alreadyIn: widget.preview?.alreadyInFor(s.playlist.id) ?? 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.stats, required this.alreadyIn});

  final PlaylistStats stats;
  final int alreadyIn;

  @override
  Widget build(BuildContext context) {
    final name = stats.playlist.name;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: BookSpine(label: name.characters.firstOrNull ?? '?'),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          '단어 ${stats.shownCount}개',
          if (alreadyIn > 0) '이미 있음 $alreadyIn',
        ].join(' · '),
      ),
      onTap: () =>
          Navigator.of(context).pop(ExistingPlaylist(stats.playlist.id)),
    );
  }
}
