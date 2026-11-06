/// Katakana OCR reads for simple kanji.
library;

Map<int, int> _byRune(Map<String, String> m) => {
  for (final MapEntry(:key, :value) in m.entries)
    key.runes.single: value.runes.single,
};

/// Katakana that look like kanji, inside a headword that has kanji.
final Map<int, int> confusableInKanji = Map.unmodifiable(
  _byRune({'タ': '夕', 'ロ': '口', 'エ': '工', 'カ': '力', 'ニ': '二', 'ハ': '八'}),
);
