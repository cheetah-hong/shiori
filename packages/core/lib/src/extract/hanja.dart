/// Korean readings of kanji words, for pairing a headword with its meaning.
///
/// Readings come from Unihan `kHangul` (data/hanja_readings.dart). A Korean
/// meaning that spells the headword's kanji (図書館 → 도서관) is content
/// evidence that the two belong together, independent of where they sit.
library;

import 'package:shiori_core/src/extract/data/hanja_readings.dart';

final Map<String, List<String>> _readings = _parse(hanjaReadingData);

Map<String, List<String>> _parse(String data) => {
  for (final entry in data.split(' '))
    if (entry.isNotEmpty)
      String.fromCharCode(entry.runes.first): entry
          .substring(String.fromCharCode(entry.runes.first).length)
          .split(','),
};

/// Korean readings of one kanji; empty when Unihan has none for it.
List<String> hanjaReadingsOf(String kanji) => _readings[kanji] ?? const [];

const int _hangulBase = 0xAC00;
const int _hangulLast = 0xD7A3;
const int _jungCount = 21;
const int _jongCount = 28;

// Initial consonant indexes (choseong).
const int _rieul = 5; // ㄹ
const int _nieun = 2; // ㄴ
const int _ieung = 11; // ㅇ

// Vowels before which ㄹ and ㄴ become ㅇ: ㅑ ㅕ ㅖ ㅛ ㅠ ㅣ.
const Set<int> _iVowels = {2, 6, 7, 12, 17, 20};

/// The initial-sound rule (두음 법칙) on the first syllable of a word:
/// 리 → 이, 료 → 요, 녀 → 여, 로 → 노.
String initialSoundRule(String syllable) {
  final c = syllable.runes.first;
  if (c < _hangulBase || c > _hangulLast) return syllable;
  final index = c - _hangulBase;
  final cho = index ~/ (_jungCount * _jongCount);
  final jung = (index % (_jungCount * _jongCount)) ~/ _jongCount;
  final jong = index % _jongCount;
  final int? to = switch (cho) {
    _rieul => _iVowels.contains(jung) ? _ieung : _nieun,
    _nieun => _iVowels.contains(jung) ? _ieung : null,
    _ => null,
  };
  if (to == null) return syllable;
  return String.fromCharCode(
    _hangulBase + (to * _jungCount + jung) * _jongCount + jong,
  );
}

bool _isKanji(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF) || c == 0x3005;

/// The Korean readings of [word]'s kanji in order, with the initial-sound
/// rule applied at the start (理由 → 이유 as well as 리유). Kana in [word]
/// are skipped (`静か` → 정). Empty when a kanji has no known reading.
/// At most [limit] spellings.
Set<String> sinoKoreanReadings(String word, {int limit = 32}) {
  final perKanji = <List<String>>[];
  String? previous;
  for (final c in word.runes) {
    if (!_isKanji(c)) continue;
    // 々 repeats the kanji before it.
    final kanji = c == 0x3005 ? previous : String.fromCharCode(c);
    if (kanji == null) return const {};
    final readings = hanjaReadingsOf(kanji);
    if (readings.isEmpty) return const {};
    perKanji.add(readings);
    previous = kanji;
  }
  if (perKanji.isEmpty) return const {};
  var spellings = <String>[''];
  for (final (i, readings) in perKanji.indexed) {
    final options = i == 0
        ? {
            for (final r in readings) ...{r, initialSoundRule(r)},
          }
        : readings.toSet();
    spellings = [
      for (final s in spellings)
        for (final r in options) s + r,
    ].take(limit).toList();
  }
  return spellings.toSet();
}

final RegExp _notHangul = RegExp(r'[^가-힣]');

/// Bracketed notes (`(시험에)떨어지다`) are explanations, not the meaning.
final RegExp _bracketed = RegExp(r'\([^()]*\)|（[^（）]*）');

/// Syllables of [korean] (spaces and punctuation ignored) that spell the
/// Korean reading of all of [word]'s kanji in a row; 0 when none does.
int hanjaMatchLength(String word, String korean) {
  final spellings = sinoKoreanReadings(word);
  if (spellings.isEmpty) return 0;
  // Each comma- or space-separated Korean word is checked from its start, so
  // a kanji word must begin a Korean word (운동 in 운동하다), not sit inside one.
  final words = korean
      .replaceAll(_bracketed, ' ')
      .split(RegExp(r'[\s,，、/·]+'))
      .map((w) => w.replaceAll(_notHangul, ''))
      .where((w) => w.isNotEmpty);
  var best = 0;
  for (final w in words) {
    for (final s in spellings) {
      if (s.length > best && w.startsWith(s)) best = s.length;
    }
  }
  return best;
}

/// Whether one of the comma-separated Korean words of [korean] is exactly a
/// Korean reading of [word] (`山` and `산, 뫼`): a one-syllable match counts
/// only when it is a whole word, so it does not match by chance inside one.
bool hanjaNamesWord(String word, String korean) {
  final spellings = sinoKoreanReadings(word);
  if (spellings.isEmpty) return false;
  return korean
      .replaceAll(_bracketed, ' ')
      .split(RegExp(r'[\s,，、/·]+'))
      .map((w) => w.replaceAll(_notHangul, ''))
      .any(spellings.contains);
}
