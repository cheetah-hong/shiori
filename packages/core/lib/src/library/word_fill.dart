import 'package:shiori_core/src/capture/text/chars.dart' show nfkc;
import 'package:shiori_core/src/extract/extracted_word.dart'
    show partOfSpeechOf;
import 'package:shiori_core/src/extract/meaning_senses.dart';
import 'package:shiori_core/src/extract/script_runs.dart' show isKanji;
import 'package:shiori_core/src/library/word_edit.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';
import 'package:shiori_core/src/ports/lexicon.dart';
import 'package:shiori_core/src/models/word_key.dart' show withoutPrintedEnding;
import 'package:shiori_core/src/study/card_example.dart'
    show kanaEntries, toHiraganaReading;

/// A kanji spelling the dictionary has for a headword typed in kana.
final class KanjiChoice {
  const KanjiChoice({
    required this.headword,
    required this.reading,
    this.pos,
    this.meaning,
  });

  final String headword;

  /// The kana that was typed.
  final String reading;
  final PartOfSpeech? pos;

  /// The first meaning the glossaries give, to tell the spellings apart.
  final String? meaning;

  @override
  bool operator ==(Object other) =>
      other is KanjiChoice &&
      other.headword == headword &&
      other.reading == reading &&
      other.pos == pos &&
      other.meaning == meaning;

  @override
  int get hashCode => Object.hash(headword, reading, pos, meaning);

  @override
  String toString() => 'KanjiChoice($headword【$reading】 $meaning)';
}

/// What the dictionaries say about a headword the learner typed.
final class WordFill {
  const WordFill({
    required this.found,
    this.readings = const [],
    this.pos,
    this.meanings = const [],
    this.kanjiChoices = const [],
  });

  /// The dictionary has no entry for it.
  static const WordFill none = WordFill(found: false);

  /// The dictionary has an entry written so.
  final bool found;

  /// The reading of a headword with kanji (empty for one in kana).
  final List<String> readings;
  final PartOfSpeech? pos;

  /// Korean meanings, best first.
  final List<String> meanings;

  /// For a headword in kana: kanji spellings of the words it may be.
  final List<KanjiChoice> kanjiChoices;

  @override
  bool operator ==(Object other) =>
      other is WordFill &&
      other.found == found &&
      listEquals(other.readings, readings) &&
      other.pos == pos &&
      listEquals(other.meanings, meanings) &&
      listEquals(other.kanjiChoices, kanjiChoices);

  @override
  int get hashCode => Object.hash(
    found,
    Object.hashAll(readings),
    pos,
    Object.hashAll(meanings),
    Object.hashAll(kanjiChoices),
  );

  @override
  String toString() =>
      'WordFill(found: $found, ${readings.join('/')}, ${pos?.badge}, '
      '$meanings, $kanjiChoices)';
}

/// Kanji spellings offered for a headword in kana, at most.
const int maxKanjiChoices = 4;

/// What [lexicon] and the glossaries ([glossary], then [fallback]) say
/// about [headword], the way the word extractor fills a dictionary word.
/// A な-adjective printed with its ending (`便利だ`) is looked up bare.
/// [readings] (a saved word's, katakana or hiragana) pick the entry of a
/// headword with kanji read so; without one of them, the common entry.
Future<WordFill> wordFill(
  String headword, {
  required Lexicon lexicon,
  required KoreanGlossary glossary,
  KoreanGlossary? fallback,
  List<String> readings = const [],
}) async {
  final head = nfkc(headword.trim());
  if (head.isEmpty) return WordFill.none;
  final glossaries = [glossary, ?fallback];
  if (!head.runes.any(isKanji)) {
    final found = await lexicon.lookup([head]);
    return _kanaFill(head, found[head] ?? const [], glossaries);
  }
  final bare = withoutPrintedEnding(head, const []);
  final found = await lexicon.lookup([head, ?bare?.headword]);
  var form = head;
  var entries = found[head] ?? const <LexiconEntry>[];
  if (entries.isEmpty && bare != null) {
    form = bare.headword;
    entries = found[form] ?? const <LexiconEntry>[];
  }
  final written = [
    for (final e in entries)
      if (!e.isKanaForm) e,
  ];
  final candidates = written.isEmpty ? entries : written;
  final (entry, reading) =
      _readAs(candidates, readings) ??
      (_likeliest(candidates), _likeliest(candidates)?.readings.firstOrNull);
  final read = [?reading];
  final pos = partOfSpeechOf(entry?.partsOfSpeech ?? const []);
  final meanings = await _meanings(
    glossaries,
    {form, ...?entry?.kanjiForms},
    readings: read,
    pos: pos,
  );
  if (entry == null && meanings.isEmpty) return WordFill.none;
  return WordFill(
    found: entry != null,
    readings: List.unmodifiable(read),
    pos: pos,
    meanings: meanings,
  );
}

/// A headword in kana: the kanji spellings of the words it may be (the
/// entries a kana word stands for first), and the meaning of the likeliest.
Future<WordFill> _kanaFill(
  String head,
  List<LexiconEntry> entries,
  List<KoreanGlossary> glossaries,
) async {
  final preferred = kanaEntries(entries);
  final ordered = [
    ...preferred,
    for (final e in entries)
      if (!preferred.contains(e)) e,
  ];
  final pos = partOfSpeechOf(ordered.firstOrNull?.partsOfSpeech ?? const []);
  final choices = <KanjiChoice>[];
  final seen = <String>{};
  for (final e in ordered) {
    final kanji = e.kanjiForms.firstOrNull;
    if (kanji == null || !seen.add(kanji)) continue;
    final ePos = partOfSpeechOf(e.partsOfSpeech);
    final meanings = await _meanings(
      glossaries,
      {kanji},
      readings: [head],
      pos: ePos,
    );
    choices.add(
      KanjiChoice(
        headword: kanji,
        reading: head,
        pos: ePos,
        meaning: meanings.firstOrNull,
      ),
    );
    if (choices.length == maxKanjiChoices) break;
  }
  var meanings = await _meanings(
    glossaries,
    {head},
    readings: [head],
    pos: pos,
  );
  if (meanings.isEmpty) meanings = [?choices.firstOrNull?.meaning];
  if (ordered.isEmpty && meanings.isEmpty) return WordFill.none;
  return WordFill(
    found: ordered.isNotEmpty,
    pos: pos,
    meanings: List.unmodifiable(meanings),
    kanjiChoices: List.unmodifiable(choices),
  );
}

/// The entry of [entries] read as one of [readings], with that reading.
(LexiconEntry?, String?)? _readAs(
  List<LexiconEntry> entries,
  List<String> readings,
) {
  for (final r in readings) {
    final want = toHiraganaReading(r.trim());
    if (want.isEmpty) continue;
    for (final e in entries) {
      for (final er in e.readings) {
        if (toHiraganaReading(er) == want) return (e, er);
      }
    }
  }
  return null;
}

/// The common entry first, else the first.
LexiconEntry? _likeliest(List<LexiconEntry> entries) {
  for (final e in entries) {
    if (e.isCommon) return e;
  }
  return entries.firstOrNull;
}

/// The meanings of the first glossary that has any for one of [forms],
/// best first, each once, at most [maxMeaningCandidates].
Future<List<String>> _meanings(
  List<KoreanGlossary> glossaries,
  Set<String> forms, {
  required List<String> readings,
  PartOfSpeech? pos,
}) => dictionaryMeanings(glossaries, forms, readings: readings, pos: pos);

/// [current] with what [fill] can add, never what the learner wrote: an
/// empty field takes the dictionary's value; a field with a value keeps it
/// and gets the dictionary's as a suggestion when they differ.
FilledWord mergeFill(WordEdit current, WordFill fill) {
  final filled = <EntryField>{};
  final written = [
    for (final r in current.readings)
      if (r.trim().isNotEmpty) r.trim(),
  ];
  var readings = current.readings;
  List<String>? readingSuggestion;
  if (fill.readings.isNotEmpty) {
    if (written.isEmpty) {
      readings = fill.readings;
      filled.add(EntryField.readings);
    } else if (!_sameReadings(written, fill.readings)) {
      readingSuggestion = fill.readings;
    }
  }
  var pos = current.pos;
  PartOfSpeech? posSuggestion;
  if (fill.pos != null) {
    if (pos == null) {
      pos = fill.pos;
      filled.add(EntryField.pos);
    } else if (pos != fill.pos) {
      posSuggestion = fill.pos;
    }
  }
  var meaning = current.meaning;
  var others = fill.meanings;
  if (meaning.trim().isEmpty && others.isNotEmpty) {
    meaning = others.first;
    others = others.sublist(1);
    filled.add(EntryField.meaning);
  }
  final kept = meaning.trim();
  return FilledWord(
    edit: WordEdit(
      headword: current.headword,
      readings: readings,
      pos: pos,
      meaning: meaning,
      example: current.example,
    ),
    filled: Set.unmodifiable(filled),
    readingSuggestion: readingSuggestion,
    posSuggestion: posSuggestion,
    meaningSuggestions: List.unmodifiable([
      for (final m in others)
        if (m.trim() != kept) m,
    ]),
  );
}

/// Every reading of [dictionary] is among [written] (katakana as hiragana).
bool _sameReadings(List<String> written, List<String> dictionary) {
  final have = {for (final r in written) toHiraganaReading(r)};
  return dictionary.every((r) => have.contains(toHiraganaReading(r)));
}

/// A word's fields after [mergeFill].
final class FilledWord {
  const FilledWord({
    required this.edit,
    this.filled = const {},
    this.readingSuggestion,
    this.posSuggestion,
    this.meaningSuggestions = const [],
  });

  final WordEdit edit;

  /// The fields the dictionary filled (they were empty).
  final Set<EntryField> filled;

  /// The dictionary's readings, when the word has others.
  final List<String>? readingSuggestion;

  /// The dictionary's class, when the word has another.
  final PartOfSpeech? posSuggestion;

  /// Other meanings to offer, best first.
  final List<String> meaningSuggestions;
}
