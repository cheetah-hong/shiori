const _smallKana = 'ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ';

/// Splits kana into morae: a small ゃゅょ (and ぁぃぅぇぉゎ) joins the kana
/// before it; ん, っ and ー are morae of their own. Hiragana and katakana
/// both work; anything else is one mora per character.
List<String> splitMorae(String kana) {
  final morae = <String>[];
  for (final rune in kana.runes) {
    final ch = String.fromCharCode(rune);
    if (_smallKana.contains(ch) && morae.isNotEmpty) {
      morae[morae.length - 1] = morae.last + ch;
    } else {
      morae.add(ch);
    }
  }
  return List.unmodifiable(morae);
}

/// Hiragana to katakana; other characters stay as they are.
String toKatakana(String kana) => String.fromCharCodes([
  for (final c in kana.runes) c >= 0x3041 && c <= 0x3096 ? c + 0x60 : c,
]);

/// Katakana to hiragana; other characters stay as they are.
String toHiragana(String kana) => String.fromCharCodes([
  for (final c in kana.runes) c >= 0x30A1 && c <= 0x30F6 ? c - 0x60 : c,
]);

/// Tokyo pitch of a word of [morae] morae with accent [accent] (0 = flat,
/// n = falls after the n-th mora), plus one slot for a particle after it:
/// true = high. 0: LHH…H|H, 1: HLL…L|L, n: LH…H(n)L…L|L.
List<bool> pitchPattern({required int morae, required int accent}) {
  if (morae < 1) throw ArgumentError.value(morae, 'morae', 'needs a mora');
  if (accent < 0 || accent > morae) {
    throw ArgumentError.value(accent, 'accent', 'outside 0…$morae');
  }
  return List.unmodifiable([
    for (var i = 0; i <= morae; i++)
      switch (accent) {
        0 => i > 0,
        1 => i == 0,
        _ => i > 0 && i < accent,
      },
  ]);
}
