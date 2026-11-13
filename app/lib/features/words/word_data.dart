/// Read models of the word screens. They refresh with [dataRevisionProvider]
/// like the other screens.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori_core/shiori_core.dart';

/// One library word (also a hidden one, or one in no playlist).
final wordProvider = FutureProvider.autoDispose.family<Word?, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(libraryRepositoryProvider).word(id);
});

/// The names of the playlists holding word [id], in the playlists' order.
final wordPlaylistNamesProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, id) async {
      ref.watch(dataRevisionProvider);
      final library = ref.watch(libraryRepositoryProvider);
      final of = (await library.playlistsOf([id]))[id] ?? const <String>{};
      return List.unmodifiable([
        for (final p in await library.playlists())
          if (of.contains(p.id)) p.name,
      ]);
    });

/// 단어 찾기: every word in a playlist (hidden ones too), folded once per
/// change of the library. Read in memory: 8,000 words take a few ms
/// (docs/verification.md 42).
final wordSearchIndexProvider = FutureProvider.autoDispose<WordSearchIndex>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  return WordSearchIndex(await ref.watch(libraryRepositoryProvider).words());
});

/// The word ids of playlist [id] (단어 찾기's 이 목록).
final playlistWordIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, id) async {
      ref.watch(dataRevisionProvider);
      final words = await ref
          .watch(libraryRepositoryProvider)
          .words(playlistId: id);
      return Set.unmodifiable({for (final w in words) w.id});
    });

/// Looks a typed headword up in the app's dictionaries (empty ones until
/// they open, or in a build without them); a saved word's [readings] pick
/// the dictionary entry read so.
typedef WordFiller =
    Future<WordFill> Function(String headword, {List<String> readings});

final wordFillerProvider = Provider<WordFiller>((ref) {
  final lexicon = ref.watch(lexiconProvider);
  final glossary = ref.watch(koreanGlossaryProvider);
  final fallback = ref.watch(wiktionaryGlossaryProvider);
  return (headword, {readings = const []}) => wordFill(
    headword,
    lexicon: lexicon,
    glossary: glossary,
    fallback: fallback,
    readings: readings,
  );
});
