/// Cell clean-up for the textbook layouts (rules 7–9).
library;

import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

final RegExp _leadingId = RegExp(r'^\s*[0-9Il|]{4}\s*');

// Checkbox squares and the POS badge are read as these glyphs.
final RegExp _overCheckbox = RegExp(r'^[□口ロコ■NLDレ目問gG8\s]+');
final RegExp _noiseRun = RegExp(r'^[□口ロコ■LDレ目問gG8]{2,}\s*');
final RegExp _noiseOne = RegExp(r'^[□口ロコ■LDレ目問gG8]\s+');

/// Headword cell without the number and checkbox noise.
///
/// [overCheckbox]: the line starts where the checkboxes are, so any leading
/// noise glyph goes (`口晴れ` → `晴れ`, `N天気` → `天気`).
String cleanHead(String s, {bool overCheckbox = false}) {
  var out = s.replaceFirst(_leadingId, '');
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

/// `あした/あす` → [あした, あす]; `–` → [].
List<String> parseReadings(String s) {
  final t = nfkc(s).replaceAll(' ', '');
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
