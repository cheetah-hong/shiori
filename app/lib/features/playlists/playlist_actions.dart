/// What the playlist screens do with the library, with the snack bar that
/// says so. They take no [BuildContext] after the first await, so an undo
/// still works once the screen is gone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/features/playlists/playlist_names.dart';
import 'package:shiori/features/study/restudy_labels.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori_core/shiori_core.dart';

void _say(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) => messenger
  ..removeCurrentSnackBar()
  ..showSnackBar(
    SnackBar(content: Text(message), action: action, persist: false),
  );

/// Runs [write]; on failure says [failure] and returns false. A storage
/// block's exception is logged, a bug is reported like any uncaught error.
Future<bool> _guarded(
  ScaffoldMessengerState messenger,
  String failure,
  Future<void> Function() write,
) async {
  try {
    await write();
    return true;
  } on LibraryException catch (e) {
    _say(messenger, e.message);
  } on Exception catch (e, stack) {
    debugPrint('playlist change failed: $e\n$stack');
    _say(messenger, failure);
  } on Error catch (e, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: stack, library: 'playlists'),
    );
    _say(messenger, failure);
  }
  return false;
}

/// `'목록'에 단어 n개 추가 · 이미 있음 k`, or `'목록'에 이미 있어요`.
String addedMessage(AddResult result) {
  final name = result.playlist.name;
  if (result.total == 0 && result.alreadyIn > 0) return "'$name'에 이미 있어요";
  return [
    "'$name'에 단어 ${result.total}개 추가",
    if (result.alreadyIn > 0) '이미 있음 ${result.alreadyIn}',
  ].join(' · ');
}

/// Hides or shows [word] and says so, with 되돌리기 after hiding.
Future<void> setWordHidden({
  required ScaffoldMessengerState messenger,
  required LibraryService library,
  required DataRevision revision,
  required Word word,
  required bool hidden,
}) async {
  final done = await _guarded(
    messenger,
    hidden ? HideLabels.hideFailed : HideLabels.restoreFailed,
    () =>
        hidden ? library.hideWords([word.id]) : library.unhideWords([word.id]),
  );
  if (!done) return;
  revision.bump();
  if (!hidden) {
    _say(messenger, HideLabels.restored(word.headword));
    return;
  }
  _say(
    messenger,
    HideLabels.hidden(word.headword),
    action: SnackBarAction(
      label: HideLabels.undo,
      onPressed: () => setWordHidden(
        messenger: messenger,
        library: library,
        revision: revision,
        word: word,
        hidden: false,
      ),
    ),
  );
}

/// Takes [word] out of the playlist, with 되돌리기 (back to its place).
Future<void> removeFromPlaylist({
  required ScaffoldMessengerState messenger,
  required LibraryService library,
  required DataRevision revision,
  required String playlistId,
  required Word word,
}) async {
  var removed = const <PlaylistEntry>[];
  final done = await _guarded(
    messenger,
    '빼지 못했어요. 다시 시도해 주세요',
    () async => removed = await library.removeWords(playlistId, [word.id]),
  );
  if (!done) return;
  revision.bump();
  _say(
    messenger,
    '「${word.headword}」 뺐어요',
    action: SnackBarAction(
      label: HideLabels.undo,
      onPressed: () async {
        if (await _guarded(
          messenger,
          '되돌리지 못했어요. 다시 시도해 주세요',
          () => library.restoreWords(removed),
        )) {
          revision.bump();
        }
      },
    ),
  );
}

/// 처음부터 다시 학습: makes [word] a new word again, with 되돌리기 (its card
/// back as it was, unless it was studied meanwhile).
Future<void> resetWord({
  required ScaffoldMessengerState messenger,
  required StudyService study,
  required DataRevision revision,
  required String playlistId,
  required Word word,
}) async {
  var removed = const <ReviewCard>[];
  final done = await _guarded(
    messenger,
    RestudyLabels.resetFailed,
    () async => removed = await study.resetWords([
      word.id,
    ], scope: PlaylistOnly(playlistId)),
  );
  if (!done) return;
  revision.bump();
  _say(
    messenger,
    RestudyLabels.wordReset(word.headword),
    action: SnackBarAction(
      label: HideLabels.undo,
      onPressed: () async {
        if (await _guarded(
          messenger,
          RestudyLabels.undoFailed,
          () => study.restoreCards(removed),
        )) {
          revision.bump();
        }
      },
    ),
  );
}

/// Adds library words to [target] (다른 목록에 추가) and says what happened.
Future<void> addWordsTo({
  required ScaffoldMessengerState messenger,
  required LibraryService library,
  required DataRevision revision,
  required List<String> wordIds,
  required AddTarget target,
}) async {
  AddResult? result;
  final done = await _guarded(
    messenger,
    '추가하지 못했어요. 다시 시도해 주세요',
    () async => result = await library.addWords(wordIds, to: target),
  );
  if (!done) return;
  revision.bump();
  if (result case final r?) _say(messenger, addedMessage(r));
}

/// Asks for a new name for [playlist] and stores it.
Future<void> renamePlaylist(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final library = ref.read(libraryServiceProvider);
  final revision = ref.read(dataRevisionProvider.notifier);
  final List<PlaylistStats> all;
  try {
    all = await ref.read(playlistsProvider.future);
  } on Exception catch (e, stack) {
    debugPrint('playlists for renaming: $e\n$stack');
    _say(messenger, '재생목록을 불러오지 못했어요. 다시 시도해 주세요');
    return;
  }
  if (!context.mounted) return;
  final name = await showPlaylistNameDialog(
    context,
    title: '이름 바꾸기',
    action: '저장',
    taken: [
      for (final s in all)
        if (s.playlist.id != playlist.id) s.playlist.name,
    ],
    initial: playlist.name,
  );
  if (name == null) return;
  if (await _guarded(
    messenger,
    '이름을 바꾸지 못했어요. 다시 시도해 주세요',
    () => library.renamePlaylist(playlist.id, name),
  )) {
    revision.bump();
  }
}

/// Asks first, then deletes [playlist] (its words and their learning
/// records stay). True when it was deleted.
Future<bool> deletePlaylist(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist, {
  required int wordCount,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final library = ref.read(libraryServiceProvider);
  final revision = ref.read(dataRevisionProvider.notifier);
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('재생목록을 삭제할까요?'),
      content: Text('단어 $wordCount개가 이 목록에서 빠져요. 단어와 학습 기록은 남아요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (sure != true) return false;
  final done = await _guarded(
    messenger,
    '삭제하지 못했어요. 다시 시도해 주세요',
    () => library.deletePlaylist(playlist.id),
  );
  if (done) revision.bump();
  return done;
}
