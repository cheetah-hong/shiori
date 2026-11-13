import 'package:shiori_core/src/capture/text/chars.dart' show nfkc;
import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/study/card_example.dart' show toHiraganaReading;

final RegExp _spaces = RegExp(r'\s+');

/// [text] as the word search compares it: NFKC, no spaces, katakana as
/// hiragana, lower case.
String searchFold(String text) {
  final normal = _needsNfkc(text) ? nfkc(text) : text;
  return toHiraganaReading(normal.replaceAll(_spaces, '')).toLowerCase();
}

/// Whether [text] has a character NFKC may change. Kana, CJK ideographs,
/// Hangul syllables and printable ASCII never change, and a library is
/// mostly those, so most words skip the (slower) normalisation.
bool _needsNfkc(String text) {
  for (final c in text.runes) {
    final stable =
        (c >= 0x20 && c <= 0x7E) ||
        (c >= 0x3041 && c <= 0x30FF && c != 0x309B && c != 0x309C) ||
        (c >= 0x3400 && c <= 0x4DBF) ||
        (c >= 0x4E00 && c <= 0x9FFF) ||
        (c >= 0xAC00 && c <= 0xD7A3);
    if (!stable) return true;
  }
  return false;
}

/// How a word matched a query, best first.
enum _Match { whole, start, middle, meaning }

final class _Entry {
  _Entry(this.word)
    : forms = {
        searchFold(word.headword),
        searchFold(word.key),
        for (final r in word.readings) searchFold(r),
      }.where((f) => f.isNotEmpty).toList(),
      meaning = searchFold(word.meaning);

  final Word word;

  /// Headword, key and readings, folded.
  final List<String> forms;
  final String meaning;

  _Match? match(String query) {
    _Match? best;
    for (final f in forms) {
      final m = f == query
          ? _Match.whole
          : f.startsWith(query)
          ? _Match.start
          : f.contains(query)
          ? _Match.middle
          : null;
      if (m != null && (best == null || m.index < best.index)) best = m;
      if (best == _Match.whole) return best;
    }
    if (best == null && meaning.contains(query)) return _Match.meaning;
    return best;
  }
}

/// The learner's words, folded once for 단어 찾기.
///
/// A query matches a word by its headword, its readings and its key (`便利だ`
/// is `便利`), folded alike, and by part of its Korean meaning. Kana finds a
/// word written in kanji by its reading. Order: the whole headword, reading
/// or key; then their start; then any part of them; then the meaning. Ties:
/// the shorter headword, then the word added first.
final class WordSearchIndex {
  WordSearchIndex(Iterable<Word> words)
    : _entries = List.unmodifiable(words.map(_Entry.new));

  final List<_Entry> _entries;

  /// How many words the index holds.
  int get length => _entries.length;

  /// The words [query] matches, best first; only those whose id is in
  /// [within] when it is given. A blank query matches nothing.
  List<Word> find(String query, {Set<String>? within}) {
    final q = searchFold(query);
    if (q.isEmpty) return const [];
    final hits = <(_Match, Word)>[
      for (final e in _entries)
        if (within == null || within.contains(e.word.id))
          if (e.match(q) case final m?) (m, e.word),
    ];
    hits.sort((a, b) {
      final byMatch = a.$1.index.compareTo(b.$1.index);
      if (byMatch != 0) return byMatch;
      final byLength = a.$2.headword.length.compareTo(b.$2.headword.length);
      if (byLength != 0) return byLength;
      final byAge = a.$2.createdAt.compareTo(b.$2.createdAt);
      return byAge != 0 ? byAge : a.$2.id.compareTo(b.$2.id);
    });
    return List.unmodifiable([for (final (_, w) in hits) w]);
  }
}
