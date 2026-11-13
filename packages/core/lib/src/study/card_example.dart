import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/models/word_key.dart';
import 'package:shiori_core/src/ports/example_sentences.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// Where the example a card shows comes from.
enum ExampleOrigin {
  /// Read from the page with the word.
  page,

  /// A Tatoeba sentence of the word's dictionary entry (the page had none).
  tatoeba,
}

/// The example a study card shows, with its translation.
final class CardExample {
  const CardExample({
    required this.ja,
    this.ko,
    this.en,
    required this.origin,
    this.surface,
  });

  /// The example read from the page (an empty translation is none).
  factory CardExample.fromPage(Example e) => CardExample(
    ja: e.ja,
    ko: e.ko.trim().isEmpty ? null : e.ko,
    origin: ExampleOrigin.page,
  );

  final String ja;

  /// Korean translation; null when there is none.
  final String? ko;

  /// English translation, only for a filled sentence without a Korean one.
  final String? en;

  final ExampleOrigin origin;

  /// How the word is written in the sentence, when known.
  final String? surface;

  /// Not from the page: the card names the source.
  bool get isFilled => origin != ExampleOrigin.page;

  @override
  bool operator ==(Object other) =>
      other is CardExample &&
      other.ja == ja &&
      other.ko == ko &&
      other.en == en &&
      other.origin == origin &&
      other.surface == surface;

  @override
  int get hashCode => Object.hash(ja, ko, en, origin, surface);

  @override
  String toString() => 'CardExample(${origin.name}: $ja / ${ko ?? en})';
}

/// The example [word]'s card shows: the page's own example when it has one
/// (nothing is looked up), else a sentence of the word's dictionary entry
/// from [examples], else null.
///
/// The entry: [lexicon]'s entries written as the headword, narrowed to the
/// word's readings (the headword itself for a word without readings) when
/// that keeps any; for a headword in kana, the entries
/// a kana word stands for ([kanaEntries]). Of the entries' sentences the
/// first whose reading is one of the word's, else the first filed under any
/// reading.
Future<CardExample?> cardExampleOf(
  Word word, {
  required Lexicon lexicon,
  required ExampleSentences examples,
}) async {
  final printed = word.example;
  if (printed != null) return CardExample.fromPage(printed);
  // A な-adjective printed with its ending (`便利だ`): the dictionary files
  // it bare, so that is asked too and used when the printed form has none.
  final bare = withoutPrintedEnding(word.headword, word.readings);
  final looked = await lexicon.lookup([word.headword, ?bare?.headword]);
  var found = looked[word.headword] ?? const <LexiconEntry>[];
  // A word written in kana keeps no readings: it is read as written (the
  // way its speech is asked, `wordSpeechFor`).
  var wordReadings = word.readings.isEmpty ? [word.headword] : word.readings;
  if (found.isEmpty && bare != null) {
    found = looked[bare.headword] ?? const <LexiconEntry>[];
    wordReadings = bare.readings;
  }
  final ids = _entryIds(wordReadings, found);
  if (ids.isEmpty) return null;
  final rows = await examples.lookup(ids);
  final readings = {for (final r in wordReadings) toHiraganaReading(r)};
  final row =
      _first(
        rows,
        ids,
        (r) => readings.contains(toHiraganaReading(r.reading)),
      ) ??
      _first(rows, ids, (r) => r.reading.isEmpty);
  if (row == null) return null;
  return CardExample(
    ja: row.ja,
    ko: row.ko,
    en: row.ko == null ? row.en : null,
    origin: ExampleOrigin.tatoeba,
    surface: row.surface,
  );
}

/// The first row of [rows] that [keep]s, by the order of [ids].
StoredExample? _first(
  List<StoredExample> rows,
  List<int> ids,
  bool Function(StoredExample) keep,
) {
  for (final id in ids) {
    for (final r in rows) {
      if (r.entryId == id && keep(r)) return r;
    }
  }
  return null;
}

List<int> _entryIds(List<String> wordReadings, List<LexiconEntry> found) {
  final written = [
    for (final e in found)
      if (!e.isKanaForm) e,
  ];
  if (written.isEmpty) {
    return _unique([for (final e in kanaEntries(found)) e.id]);
  }
  final readings = {for (final r in wordReadings) toHiraganaReading(r)};
  final narrowed = [
    for (final e in written)
      if (e.readings.any((r) => readings.contains(toHiraganaReading(r)))) e,
  ];
  return _unique([for (final e in narrowed.isEmpty ? written : narrowed) e.id]);
}

/// The entries a word written in kana stands for, by the first rule that
/// keeps any: kana-only and common; usually written in kana and common;
/// kana-only; usually written in kana; common; else all of them
/// (the particle は before 歯·葉, こう → 斯う before 稿·項).
List<LexiconEntry> kanaEntries(List<LexiconEntry> found) {
  final kana = [
    for (final e in found)
      if (e.isKanaForm) e,
  ];
  for (final keep in <bool Function(LexiconEntry)>[
    (e) => e.kanjiForms.isEmpty && e.isCommon,
    (e) => e.usuallyKana && e.isCommon,
    (e) => e.kanjiForms.isEmpty,
    (e) => e.usuallyKana,
    (e) => e.isCommon,
  ]) {
    final kept = [
      for (final e in kana)
        if (keep(e)) e,
    ];
    if (kept.isNotEmpty) return kept;
  }
  return kana;
}

List<int> _unique(List<int> ids) => ids.toSet().toList();

/// [reading] with katakana as hiragana (ー stays), to compare readings.
String toHiraganaReading(String reading) => String.fromCharCodes([
  for (final c in reading.runes) c >= 0x30A1 && c <= 0x30F6 ? c - 0x60 : c,
]);
