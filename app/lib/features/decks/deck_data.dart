import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';

/// The built-in deck file (tools/decks/build_decks.py, built like the
/// dictionary assets and not committed).
const builtinDecksAsset = 'assets/decks/jlpt.json';

/// The built-in decks, read once from the app's assets; null in a build
/// without the deck file (a debug build). A file that does not read as
/// decks is an error.
final builtinDecksProvider = FutureProvider<BuiltinDeckSet?>((ref) async {
  final String text;
  try {
    text = await rootBundle.loadString(builtinDecksAsset);
  } on FlutterError catch (e) {
    debugPrint('built-in decks not in this build: ${e.message}');
    return null;
  }
  return parseBuiltinDecks(text);
});

/// The dictionaries a deck's meanings and classes come from.
final class DeckDictionaries {
  const DeckDictionaries({
    required this.lexicon,
    required this.glossary,
    this.fallback,
  });

  final Lexicon lexicon;
  final KoreanGlossary glossary;

  /// The Wiktionary fallback glossary, when its asset opened.
  final KoreanGlossary? fallback;
}

/// The opened dictionaries; null when JMdict or the Korean glossary did not
/// open (a deck cannot be added then: every word would be left out).
final deckDictionariesProvider = FutureProvider<DeckDictionaries?>((ref) async {
  final dictionary = await ref.watch(bundledDictionaryProvider.future);
  final glossary = await ref.watch(bundledGlossaryProvider.future);
  if (!dictionary.isAvailable || !glossary.isAvailable) return null;
  return DeckDictionaries(
    lexicon: dictionary.lexicon,
    glossary: glossary.glossary,
    fallback: glossary.wiktionary,
  );
});

/// The playlist [deck] was added as (the one named like it), if any.
PlaylistStats? deckPlaylistOf(BuiltinDeck deck, List<PlaylistStats> lists) {
  final key = playlistNameKey(deck.name);
  for (final s in lists) {
    if (playlistNameKey(s.playlist.name) == key) return s;
  }
  return null;
}
