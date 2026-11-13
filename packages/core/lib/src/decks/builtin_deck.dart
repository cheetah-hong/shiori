import 'dart:convert';

import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/word_key.dart';

/// The `format` of a built-in deck file.
const String builtinDeckFormat = 'shiori-decks';

/// The newest built-in deck file version this build reads.
const int builtinDeckVersion = 1;

/// One word of a built-in deck: how it is shown, read, and which dictionary
/// entry it is.
final class DeckWord {
  const DeckWord({
    required this.headword,
    required this.reading,
    required this.entryId,
    this.lookupForm,
    this.meaning,
  });

  final String headword;

  /// The reading in kana (the word itself for a word written in kana).
  final String reading;

  /// JMdict `ent_seq` of the word.
  final int entryId;

  /// The dictionary spelling to ask for the meaning first (the entry's
  /// common kanji form), when it is not [headword].
  final String? lookupForm;

  /// A meaning written for the deck, used only when the dictionaries have
  /// none.
  final String? meaning;

  /// Readings as a saved word keeps them: none for a word written in kana.
  List<String> get readings => _isKana(headword) ? const [] : [reading];

  @override
  bool operator ==(Object other) =>
      other is DeckWord &&
      other.headword == headword &&
      other.reading == reading &&
      other.entryId == entryId &&
      other.lookupForm == lookupForm &&
      other.meaning == meaning;

  @override
  int get hashCode =>
      Object.hash(headword, reading, entryId, lookupForm, meaning);

  @override
  String toString() => 'DeckWord($headword【$reading】#$entryId)';
}

/// A word list that comes with the app (JLPT N5 대비 …).
final class BuiltinDeck {
  const BuiltinDeck({
    required this.id,
    required this.name,
    required this.level,
    required this.words,
  });

  final String id;

  /// The name of the playlist the deck is added as.
  final String name;

  /// `N5` … `N1`.
  final String level;

  /// In the order new words are studied.
  final List<DeckWord> words;

  @override
  bool operator ==(Object other) =>
      other is BuiltinDeck &&
      other.id == id &&
      other.name == name &&
      other.level == level &&
      listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(id, name, level, Object.hashAll(words));

  @override
  String toString() => 'BuiltinDeck($id, ${words.length} words)';
}

/// Where the deck lists come from, for the 정보 screen and the deck screen.
final class DeckSource {
  const DeckSource({
    required this.name,
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.url,
  });

  final String name;
  final String author;
  final String license;
  final String licenseUrl;
  final String url;
}

/// Every deck of the deck file, with its edition and sources.
final class BuiltinDeckSet {
  const BuiltinDeckSet({
    required this.edition,
    required this.sources,
    required this.decks,
  });

  /// The day the file was built (`YYYY-MM-DD`).
  final String edition;
  final List<DeckSource> sources;
  final List<BuiltinDeck> decks;
}

/// The deck file [json] (`tools/decks/build_decks.py`), every field checked;
/// a [FormatException] for the first problem.
BuiltinDeckSet parseBuiltinDecks(String json) {
  final Object? document;
  try {
    document = jsonDecode(json);
  } on FormatException catch (e) {
    throw FormatException('deck file is not JSON: ${e.message}');
  }
  final top = _object(document, 'deck file', _topKeys);
  if (top['format'] != builtinDeckFormat) {
    throw FormatException('not a deck file', top['format']);
  }
  final version = top['version'];
  if (version is! int || version < 1 || version > builtinDeckVersion) {
    throw FormatException('deck file version this app cannot read', version);
  }
  final decks = [
    for (final (i, d) in _list(top['decks'], 'decks').indexed)
      _deck(d, 'deck $i'),
  ];
  if (decks.isEmpty) throw const FormatException('deck file has no decks');
  final ids = <String>{};
  for (final d in decks) {
    if (!ids.add(d.id)) throw FormatException('deck id twice', d.id);
  }
  return BuiltinDeckSet(
    edition: _text(top, 'edition', 'deck file'),
    sources: List.unmodifiable([
      for (final (i, s) in _list(top['sources'], 'sources').indexed)
        _source(s, 'source $i'),
    ]),
    decks: List.unmodifiable(decks),
  );
}

const Set<String> _topKeys = {
  'format',
  'version',
  'edition',
  'sources',
  'decks',
};
const Set<String> _deckKeys = {'id', 'name', 'level', 'words'};
const Set<String> _wordKeys = {'h', 'r', 'e', 'l', 'm'};
const Set<String> _sourceKeys = {
  'name',
  'author',
  'license',
  'licenseUrl',
  'url',
};

BuiltinDeck _deck(Object? raw, String where) {
  final d = _object(raw, where, _deckKeys);
  final words = [
    for (final (i, w) in _list(d['words'], '$where words').indexed)
      _word(w, '$where word $i'),
  ];
  if (words.isEmpty) throw FormatException('$where has no words');
  final keys = <String>{};
  for (final w in words) {
    if (!keys.add(wordKey(w.headword))) {
      throw FormatException('$where has a word twice', w.headword);
    }
  }
  return BuiltinDeck(
    id: _text(d, 'id', where),
    name: _text(d, 'name', where),
    level: _text(d, 'level', where),
    words: List.unmodifiable(words),
  );
}

DeckWord _word(Object? raw, String where) {
  final w = _object(raw, where, _wordKeys);
  final entry = w['e'];
  if (entry is! int || entry <= 0) {
    throw FormatException('$where needs a positive integer entry', entry);
  }
  return DeckWord(
    headword: _text(w, 'h', where),
    reading: _text(w, 'r', where),
    entryId: entry,
    lookupForm: w.containsKey('l') ? _text(w, 'l', where) : null,
    meaning: w.containsKey('m') ? _text(w, 'm', where) : null,
  );
}

DeckSource _source(Object? raw, String where) {
  final s = _object(raw, where, _sourceKeys);
  return DeckSource(
    name: _text(s, 'name', where),
    author: _text(s, 'author', where),
    license: _text(s, 'license', where),
    licenseUrl: _text(s, 'licenseUrl', where),
    url: _text(s, 'url', where),
  );
}

/// [raw] as an object with only [allowed] keys.
Map<String, Object?> _object(Object? raw, String where, Set<String> allowed) {
  if (raw is! Map<String, Object?>) {
    throw FormatException('$where must be an object');
  }
  for (final key in raw.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('$where has an unknown key', key);
    }
  }
  return raw;
}

List<Object?> _list(Object? raw, String where) =>
    raw is List<Object?> ? raw : throw FormatException('$where must be a list');

/// The text at [key], not blank.
String _text(Map<String, Object?> map, String key, String where) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$where needs "$key"', value);
  }
  return value;
}

/// Hiragana, katakana and the long-vowel mark only.
bool _isKana(String text) =>
    text.isNotEmpty && text.runes.every((c) => c >= 0x3041 && c <= 0x30FF);
