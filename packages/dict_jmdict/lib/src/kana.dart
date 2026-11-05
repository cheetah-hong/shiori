/// Character classes and hiragana/katakana folding.
library;

bool isHiragana(int rune) => rune >= 0x3041 && rune <= 0x309F;

bool isKatakana(int rune) => rune >= 0x30A0 && rune <= 0x30FF;

bool isKana(int rune) => isHiragana(rune) || isKatakana(rune);

/// CJK ideographs (with extension A and compatibility ideographs) plus 々 and 〆.
bool isKanji(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0x20000 && rune <= 0x2FFFF) ||
    rune == 0x3005 ||
    rune == 0x3006;

bool hasKanji(String s) => s.runes.any(isKanji);

bool isKanaOnly(String s) => s.isNotEmpty && s.runes.every(isKana);

/// ァ..ヶ become ぁ..ゖ. ー, ・ and other symbols stay as they are.
String toHiragana(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r),
);

/// ぁ..ゖ become ァ..ヶ.
String toKatakana(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x3041 && r <= 0x3096 ? r + 0x60 : r),
);

/// The same text in its plain, hiragana and katakana spellings, without duplicates.
Set<String> kanaSpellings(String s) => {s, toHiragana(s), toKatakana(s)};

const _voiced = 'がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ';
const _plain = 'かきくけこさしすせそたちつてとはひふへほはひふへほ';

/// The reading without rendaku on its first kana (がわ → かわ), or null if
/// the first kana is not a voiced hiragana (fold katakana first).
String? withoutRendaku(String reading) {
  if (reading.isEmpty) return null;
  final i = _voiced.indexOf(reading[0]);
  return i < 0 ? null : _plain[i] + reading.substring(1);
}
