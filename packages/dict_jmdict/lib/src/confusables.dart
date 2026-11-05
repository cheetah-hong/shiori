/// Glyphs that OCR confuses, and how one OCR'd string can stand for a
/// dictionary form.
library;

import 'package:dict_jmdict/src/kana.dart';
import 'package:dict_jmdict/src/models.dart';

/// Whole headword read as one of these is the kanji on the right
/// (same table as the reference corrector, `parse_eval.py` rule 11).
const Map<String, String> confusableWhole = {
  'ー': '一',
  '-': '一',
  '—': '一',
  '+': '十',
  'ニ': '二',
  'ハ': '八',
  'ロ': '口',
};

/// Katakana read in place of a look-alike kanji (same table as rule 11).
const Map<String, String> confusableInKanji = {
  'タ': '夕',
  'ロ': '口',
  'エ': '工',
  'カ': '力',
  'ニ': '二',
  'ハ': '八',
};

/// Look-alike groups from both tables, used in either direction:
/// {一 ー - —} {十 +} {二 ニ} {八 ハ} {口 ロ} {夕 タ} {工 エ} {力 カ}.
final Map<int, int> _group = _buildGroups();

Map<int, int> _buildGroups() {
  final group = <int, int>{};
  final pairs = [...confusableWhole.entries, ...confusableInKanji.entries];
  for (final MapEntry(:key, :value) in pairs) {
    final kanji = value.runes.single;
    group[key.runes.single] = kanji;
    group[kanji] = kanji;
  }
  return Map.unmodifiable(group);
}

/// Whether [a] and [b] are in the same look-alike group.
bool areConfusable(int a, int b) =>
    a != b && _group[a] != null && _group[a] == _group[b];

/// The look-alikes of [rune] (not including itself).
List<int> confusablesOf(int rune) {
  final g = _group[rune];
  if (g == null) return const [];
  return [
    for (final MapEntry(:key, :value) in _group.entries)
      if (value == g && key != rune) key,
  ];
}

/// How [ocr] would have to change, glyph by glyph, to become [form];
/// null when the two differ in length or in a glyph pair that is neither a
/// look-alike nor the same kana in the other script.
List<GlyphEdit>? glyphEdits(String ocr, String form) {
  final a = ocr.runes.toList();
  final b = form.runes.toList();
  if (a.length != b.length) return null;
  final edits = <GlyphEdit>[];
  for (var i = 0; i < a.length; i++) {
    if (a[i] == b[i]) continue;
    final from = String.fromCharCode(a[i]);
    final to = String.fromCharCode(b[i]);
    if (areConfusable(a[i], b[i])) {
      edits.add(GlyphEdit(i, from, to, GlyphEditKind.lookAlike));
    } else if (isKana(a[i]) &&
        isKana(b[i]) &&
        toHiragana(from) == toHiragana(to)) {
      edits.add(GlyphEdit(i, from, to, GlyphEditKind.kanaScript));
    } else {
      return null;
    }
  }
  return List.unmodifiable(edits);
}

/// Every string [ocr] could stand for with at most [maxEdits] glyph changes,
/// fewest changes first; at most [cap] strings, [ocr] itself included.
List<String> glyphVariants(String ocr, {int maxEdits = 3, int cap = 200}) {
  if (cap <= 0) return const [];
  final runes = ocr.runes.toList();
  final options = [
    for (final r in runes)
      {
        ...confusablesOf(r),
        if (isKana(r))
          ...kanaSpellings(String.fromCharCode(r)).map((s) => s.runes.single),
      }..remove(r),
  ];
  final out = <String>[ocr];
  var frontier = <List<int>>[runes];
  final seen = {ocr};
  for (
    var depth = 0;
    depth < maxEdits && frontier.isNotEmpty && out.length < cap;
    depth++
  ) {
    final next = <List<int>>[];
    for (final current in frontier) {
      for (var i = 0; i < current.length; i++) {
        if (current[i] != runes[i]) continue; // change each position once
        for (final alt in options[i]) {
          final variant = [...current]..[i] = alt;
          final s = String.fromCharCodes(variant);
          if (!seen.add(s)) continue;
          out.add(s);
          if (out.length >= cap) return List.unmodifiable(out);
          next.add(variant);
        }
      }
    }
    frontier = next;
  }
  return List.unmodifiable(out);
}
