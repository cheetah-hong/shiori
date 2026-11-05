/// Index keys: the same rules as tools/dict/build_ko_glossary.py
/// (`pair_key`), checked by both against tools/dict/testdata/ko_glossary_keys.json.
library;

/// Same set as `_NOISE` in build_ko_glossary.py (not `\s`: Python and Dart
/// differ on it).
final _noise = RegExp('[ \t\n\r\f\v 　﻿〜～~…]');
final _parens = RegExp(r'[（(][^）)]*[）)]');
const _endings = ['する', 'だ', 'な'];
const _kanjiOnlyEndings = {'だ', 'な'};

/// The index keys of a written form and its reading ('' for none).
///
/// Drops spaces, 〜 and …, a する / だ / な ending (だ and な only after kanji,
/// する after kanji or two kana), other parenthesised parts, and folds
/// katakana to hiragana: 有名だ / ゆうめいだ → 有名 / ゆうめい,
/// 勉強(する) → 勉強, レストラン → れすとらん, ただ stays ただ.
(String, String) pairKey(String form, String reading) {
  final (key, readingKey, _) = keysAndEnding(form, reading);
  return (key, readingKey);
}

/// [pairKey] and the ending it dropped (`する`, `だ`, `な` or '').
(String, String, String) keysAndEnding(String form, String reading) {
  final (f, r, ending) = _stripEnding(
    form.replaceAll(_noise, ''),
    reading.replaceAll(_noise, ''),
  );
  return (
    toHiragana(f.replaceAll(_parens, '')),
    toHiragana(r.replaceAll(_parens, '')),
    ending,
  );
}

(String, String, String) _stripEnding(String form, String reading) {
  final kanji = hasKanji(form);
  for (final ending in _endings) {
    if (_kanjiOnlyEndings.contains(ending) && !kanji) continue;
    final how = _endingOf(form, ending);
    if (how == _Ending.none) continue;
    // A kana word needs two kana before する (かする is a verb of its own).
    if (how == _Ending.written && !kanji && form.length - ending.length < 2) {
      continue;
    }
    return (
      _cut(form, ending, how),
      _cut(reading, ending, _endingOf(reading, ending)),
      ending,
    );
  }
  return (form, reading, '');
}

enum _Ending { none, written, optional }

_Ending _endingOf(String s, String ending) {
  if (s.endsWith('($ending)') || s.endsWith('（$ending）')) {
    return _Ending.optional;
  }
  return s.length > ending.length && s.endsWith(ending)
      ? _Ending.written
      : _Ending.none;
}

String _cut(String s, String ending, _Ending how) => switch (how) {
  _Ending.none => s,
  _Ending.written => s.substring(0, s.length - ending.length),
  _Ending.optional => s.substring(0, s.length - ending.length - 2),
};

/// CJK ideographs (with extension A and compatibility ideographs) plus 々 and 〆.
bool isKanji(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0x20000 && rune <= 0x2FFFF) ||
    rune == 0x3005 ||
    rune == 0x3006;

bool hasKanji(String s) => s.runes.any(isKanji);

/// ァ..ヶ become ぁ..ゖ. ー and other marks stay.
String toHiragana(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r),
);
