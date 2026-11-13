import 'package:shiori_core/src/decks/builtin_deck.dart';
import 'package:shiori_core/src/extract/extracted_word.dart'
    show partOfSpeechOf;
import 'package:shiori_core/src/extract/meaning_senses.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// A deck ready to add: its words with meaning and class, and the words
/// left out for want of a meaning.
final class DeckDraft {
  const DeckDraft({
    required this.deck,
    required this.draft,
    required this.withoutMeaning,
  });

  final BuiltinDeck deck;

  /// The words that have a meaning, in deck order.
  final CaptureDraft draft;

  /// Words no dictionary (and the deck itself) gives a meaning for.
  final List<DeckWord> withoutMeaning;
}

/// Words between two progress reports.
const int _progressStep = 50;

/// [deck]'s words as a draft to add, filled the way the word extractor
/// fills a dictionary word: the class of the deck's entry ([lexicon]), the
/// first sense [glossary] gives (with that class as its hint; the deck's
/// lookup spelling, then the shown one, then the entry's other kanji forms),
/// else [fallback]'s, else the deck's own meaning. Words left with none are left out, in
/// [DeckDraft.withoutMeaning]. [onProgress] hears (words done, all words).
///
/// A glossary that fails throws: the caller says adding failed rather than
/// leaving every word out.
Future<DeckDraft> deckDraft(
  BuiltinDeck deck, {
  required Lexicon lexicon,
  required KoreanGlossary glossary,
  KoreanGlossary? fallback,
  void Function(int done, int total)? onProgress,
}) async {
  final found = await lexicon.lookup({
    for (final w in deck.words) ...[w.headword, ?w.lookupForm],
  });
  final glossaries = [glossary, ?fallback];
  final entries = <CapturedEntry>[];
  final without = <DeckWord>[];
  final total = deck.words.length;
  for (final (i, w) in deck.words.indexed) {
    final entry = _entryOf(w, found);
    final pos = partOfSpeechOf(entry?.partsOfSpeech ?? const []);
    final meaning = await _meaningOf(w, entry, pos, glossaries) ?? w.meaning;
    if (meaning == null || meaning.trim().isEmpty) {
      without.add(w);
    } else {
      entries.add(
        CapturedEntry(
          headword: w.headword,
          readings: w.readings,
          pos: pos,
          meaning: meaning,
        ),
      );
    }
    final done = i + 1;
    if (done % _progressStep == 0 || done == total) {
      onProgress?.call(done, total);
    }
  }
  return DeckDraft(
    deck: deck,
    draft: CaptureDraft(entries: List.unmodifiable(entries)),
    withoutMeaning: List.unmodifiable(without),
  );
}

/// The deck's entry among those written as the word's spellings.
LexiconEntry? _entryOf(DeckWord w, Map<String, List<LexiconEntry>> found) {
  for (final form in [?w.lookupForm, w.headword]) {
    for (final e in found[form] ?? const <LexiconEntry>[]) {
      if (e.id == w.entryId) return e;
    }
  }
  return null;
}

/// The first sense of the first glossary that has one, under the word's
/// spellings (and their forms without an optional prefix): the deck's
/// lookup spelling, the shown one, then the other kanji forms of its entry
/// (the same word, asked with its reading).
Future<String?> _meaningOf(
  DeckWord w,
  LexiconEntry? entry,
  PartOfSpeech? pos,
  List<KoreanGlossary> glossaries,
) async => (await dictionaryMeanings(
  glossaries,
  {?w.lookupForm, w.headword, ...?entry?.kanjiForms},
  readings: [w.reading],
  pos: pos,
  limit: 1,
)).firstOrNull;
