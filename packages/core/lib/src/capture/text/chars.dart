/// Character classes used by the textbook templates.
///
/// Ranges are copied from the reference parser (`tools/reference/parse_eval.py`)
/// and work on Unicode code points (`String.runes`), like Python strings do.
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

bool isHira(int c) => c >= 0x3040 && c <= 0x309F;
bool isKata(int c) => c >= 0x30A0 && c <= 0x30FF;
bool isKanji(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) || c == 0x3005 || c == 0x3006;
bool isHangul(int c) => c >= 0xAC00 && c <= 0xD7A3;

final Set<int> _jpExtra = '、。「」？！・ー〜?!，,0123456789０１２３４５６７８９'.runes.toSet();

/// Japanese sentence characters: kana, kanji and the punctuation/digits of a sentence.
bool isJp(int c) =>
    isHira(c) || isKata(c) || isKanji(c) || _jpExtra.contains(c);

/// Unicode White_Space, the set Dart's `trim` and RegExp `\s` use.
bool isSpace(int c) =>
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    c == 0x85 ||
    c == 0xA0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000 ||
    c == 0xFEFF;

/// True when [s] (ignoring ASCII spaces and `/`) is non-empty and only kana.
bool kanaOnly(String s) {
  final rest = s.replaceAll(' ', '').replaceAll('/', '');
  return rest.isNotEmpty && rest.runes.every((c) => isHira(c) || isKata(c));
}

/// Share of non-space characters of [s] that satisfy [pred]; 0 for blank text.
double ratio(String s, bool Function(int) pred) {
  final chars = s.runes.where((c) => !isSpace(c)).toList();
  if (chars.isEmpty) return 0.0;
  return chars.where(pred).length / chars.length;
}

bool containsKanji(String s) => s.runes.any(isKanji);
bool containsKata(String s) => s.runes.any(isKata);

final RegExp _periodBetweenHangul = RegExp(r'(?<=[가-힣])\.\s+(?=[가-힣])');

/// A comma between Korean words read as a period: `싸다. 포장하다` →
/// `싸다, 포장하다` (meanings and DAY titles).
String fixKoreanPeriods(String s) => s.replaceAll(_periodBetweenHangul, ', ');

/// Unicode NFKC: full-width forms to ASCII, compatibility jamo to conjoining jamo.
String nfkc(String s) => unorm.nfkc(s);
