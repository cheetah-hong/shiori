import 'package:shiori_core/shiori_core.dart';

/// A made-up library word with id [id].
Word seedWord(
  String id,
  String headword, {
  required DateTime at,
  DateTime? hiddenAt,
  String meaning = '뜻',
}) => Word(
  id: id,
  headword: headword,
  readings: const ['よみ'],
  meaning: meaning,
  createdAt: at,
  hiddenAt: hiddenAt,
);

/// Stores playlist [playlistId] (made if missing) and [words] in it, in
/// their order. Words already in the library are only added to it.
Future<Playlist> seedPlaylist(
  LibraryRepository library,
  String playlistId,
  List<Word> words, {
  required DateTime at,
  String? name,
}) async {
  final existing = await library.playlist(playlistId);
  final playlist =
      existing ??
      Playlist(
        id: playlistId,
        name: name ?? playlistId,
        createdAt: at,
        position: (await library.playlists()).length,
      );
  if (existing == null) await library.savePlaylist(playlist);
  final fresh = [
    for (final w in words)
      if (await library.word(w.id) == null) w,
  ];
  await library.insertWords(fresh);
  await library.addToPlaylist(playlistId, [
    for (final w in words) w.id,
  ], at: at);
  return playlist;
}
