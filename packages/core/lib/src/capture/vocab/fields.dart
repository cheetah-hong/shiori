/// Cell clean-up for the textbook layouts (rules 7–9).
library;

import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

/// The legend at the top (`★ 표시 = …`), the DAY tab and the mp3 note are not words.
final RegExp legendPattern = RegExp(
  r'표시\s*=|기출 단어|^\s*DAY(?![\p{L}\p{N}_])|^\s*PART(?![\p{L}\p{N}_])|mp3',
  unicode: true,
);

final RegExp _leadingId = RegExp(r'^\s*[0-9Il|]{4}\s*');

/// What OCR returns for the digits of a word number: 1 as I, l or |, 0 as O or D.
const String ocrDigits = '0-9OoDIl|';

/// The 동 badge read as `8` in front of a meaning (fixed in the corrector chain).
final RegExp eightBadge = RegExp(r'^8(?:\s*[.:·]?\s+|$)');

/// A number with 0 read as O / D and the first checkbox read as O (`1212O`).
final RegExp _leadingOcrId = RegExp('^\\s*([$ocrDigits]{4})[Oo]?\\s*');
final RegExp _asciiDigit = RegExp('[0-9]');

/// The checkbox edge read as a bar in front of a cell (`|揺れる`, `| ゆれる`).
final RegExp _leadingBar = RegExp(r'^[|｜]+(?=\S)');
final RegExp _leadingBarSpaced = RegExp(r'^\s*[|｜]\s*');

// Checkbox squares and the POS badge are read as these glyphs.
final RegExp _overCheckbox = RegExp(r'^[□口ロコ■NLDレ目問gG8\s]+');
final RegExp _noiseRun = RegExp(r'^[□口ロコ■LDレ目問gG8]{2,}\s*');
final RegExp _noiseOne = RegExp(r'^[□口ロコ■LDレ目問gG8]\s+');

/// Headword cell without the number and checkbox noise.
///
/// [overCheckbox]: the line starts where the checkboxes are, so any leading
/// noise glyph goes (`口晴れ` → `晴れ`, `N天気` → `天気`).
String cleanHead(String s, {bool overCheckbox = false}) {
  var out = _dropOcrId(s).replaceFirst(_leadingId, '');
  out = out.replaceFirst(_leadingBar, '');
  if (overCheckbox) out = out.replaceFirst(_overCheckbox, '');
  out = out.replaceFirst(_noiseRun, '').replaceFirst(_noiseOne, '');
  return out.replaceAll('★', '').replaceAll(' ', '').trim();
}

// OCR misreads: 통 → 동, 몀 → 명.
const Map<String, String> _posBadges = {
  '명': '명',
  '몀': '명',
  '동': '동',
  '통': '동',
  '형': '형',
  'い형': 'い형',
  'な형': 'な형',
  '부': '부',
  '접': '접',
  '감': '감',
  '연': '연',
  '조': '조',
};
final RegExp _posPrefix = RegExp(
  r'^(い형|な형|명|몀|동|통|형|부|접|감|연|조)(?:\s*[.:·]?\s+|$)',
);

/// First letters of the POS badges (a badge glued to the meaning starts with one).
const String badgeGlyphs = '명몀동통형부접감연조';

/// Splits the leading POS badge off a meaning: `명 강, 개천` → (noun, `강, 개천`).
(PartOfSpeech?, String) splitPos(String meaning) {
  final m = _posPrefix.firstMatch(meaning);
  if (m == null) return (null, meaning);
  return (
    PartOfSpeech.fromBadge(_posBadges[m.group(1)]),
    meaning.substring(m.end).trim(),
  );
}

final RegExp _spaces = RegExp(r'\s+');

String cleanMeaning(String s) {
  final normalized = nfkc(s).replaceAll('，', ',');
  return stripChars(normalized.replaceAll(_spaces, ' '), ' .');
}

/// A lone dash in the reading column means a kana word with no separate reading.
const Set<String> _noReading = {'-', '–', '—', 'ー', '−', '一', ''};
final RegExp _notKana = RegExp(r'[^぀-ヿ]');

/// A number at the start of a cell read with O / D for 0 (needs two real digits,
/// so a word starting with those letters stays).
String _dropOcrId(String s) {
  final m = _leadingOcrId.firstMatch(s);
  if (m == null || _asciiDigit.allMatches(m.group(1)!).length < 2) return s;
  return s.substring(m.end);
}

final RegExp _spacedSlash = RegExp(r'\s*/\s*');
final RegExp _space = RegExp(r'\s+');

/// The reading cell text without the bar noise in front and without other
/// columns' text glued after a space (`ひかる で` → `ひかる`).
String readingText(String s) =>
    _withoutBar(s).replaceAll(_spacedSlash, '/').trim().split(_space).first;

String _withoutBar(String s) => nfkc(s).replaceFirst(_leadingBarSpaced, '');

/// The dash printed in the reading column of a kana word.
const Set<String> readingDashes = {'-', '–', '—', '−', '一'};

/// Whether a cell looks like a reading: kana, or the dash of a kana word.
/// [firstToken]: judge only the text before the first space.
bool isReadingCell(String s, {bool firstToken = false}) {
  final t = firstToken ? readingText(s) : _withoutBar(s).trim();
  return kanaOnly(t) || readingDashes.contains(t);
}

/// `あした/あす` → [あした, あす]; `–` → [].
List<String> parseReadings(String s) {
  final t = readingText(s);
  if (_noReading.contains(t)) return const [];
  return List.unmodifiable([
    for (final part in t.split('/'))
      if (part.replaceAll(_notKana, '') case final kana when kana.isNotEmpty)
        kana,
  ]);
}

final RegExp _dotSeparator = RegExp(r'\s*[•·・]\s*');

/// `여행 • 교통` → `여행·교통`.
String normTitle(String t) => t.trim().replaceAll(_dotSeparator, '·');
