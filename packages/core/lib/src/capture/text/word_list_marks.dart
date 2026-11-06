/// Marks word lists print around their words, as OCR reads them: the POS
/// badge in front of a meaning and the dash of an empty reading cell (used by
/// `extract/fragment_collector.dart`).
library;

/// POS badges as OCR reads them → the badge they are. OCR misreads: 통 → 동,
/// 몀 → 명; the い of い형 read as 니, the な of な형 read as a fraction (⅓,
/// ⅛; 1⁄3, 1⁄8 after NFKC).
const Map<String, String> posBadges = {
  '명': '명',
  '몀': '명',
  '동': '동',
  '통': '동',
  '형': '형',
  'い형': 'い형',
  '니형': 'い형',
  'な형': 'な형',
  '⅓형': 'な형',
  '1⁄3형': 'な형',
  '⅛형': 'な형',
  '1⁄8형': 'な형',
  '부': '부',
  '접': '접',
  '감': '감',
  '연': '연',
  '조': '조',
};

/// [posBadges] as one alternation, longest first (so `い형` is not read as
/// `형`).
String badgeAlternation(Iterable<String> badges) =>
    (badges.toList()..sort((a, b) => b.length - a.length))
        .map(RegExp.escape)
        .join('|');

/// What separates a badge from the meaning after it: spaces, maybe after a
/// dot or colon the OCR read off the badge's edge (`몀. 산`).
const String badgeSeparator = r'(?:\s*[.:·]?\s+|$)';

/// Dashes a word list prints in the reading cell of a kana word.
const Set<String> readingDashes = {'-', '–', '—', '−', '一'};

/// Every glyph OCR reads for that dash (also the long vowel mark).
const Set<String> blankCellMarks = {...readingDashes, 'ー'};
