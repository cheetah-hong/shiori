/// Glyphs OCR confuses with simple kanji (rule 11).
library;

Map<int, int> _byRune(Map<String, String> m) => {
  for (final MapEntry(:key, :value) in m.entries)
    key.runes.single: value.runes.single,
};

/// A whole headword that is one of these is the kanji on the right.
final Map<String, String> confusableWhole = Map.unmodifiable({
  'ー': '一',
  '-': '一',
  '—': '一',
  '+': '十',
  'ニ': '二',
  'ハ': '八',
  'ロ': '口',
});

/// Katakana that look like kanji, inside a headword that has kanji.
final Map<int, int> confusableInKanji = Map.unmodifiable(
  _byRune({'タ': '夕', 'ロ': '口', 'エ': '工', 'カ': '力', 'ニ': '二', 'ハ': '八'}),
);
