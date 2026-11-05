/// DAY number, DAY title and page number (rule 12).
library;

import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/py.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/ocr.dart';

// `\b` after a word character, with Python's Unicode notion of a word character.
const String _wordEnd = r'(?![\p{L}\p{N}_])';

final RegExp _jaDay = RegExp('DAY\\s*0?([0-9]{1,2})$_wordEnd', unicode: true);
final RegExp _footer = RegExp(
  r'DAY\s*(\S{1,2})\s+(.+?)\s+([0-9]{1,3})\s*$',
  unicode: true,
);
final RegExp _pageLine = RegExp(r'^(\p{Nd}{1,3})\s+\P{Nd}', unicode: true);

/// DAY digits misread as Hangul: `01` looks like `ㅇ` + `ㅣ`.
/// `ᄋ1` is the NFKC form of `ㅇ1`; the reference only listed the latter.
const Map<String, String> _dayMisreads = {'이': '01', 'ㅇ1': '01', 'ᄋ1': '01'};

/// The page footer (`PART … | DAY 20 여행·교통 140`) in the Korean pass.
bool isFooterLine(String text) => _footer.hasMatch(nfkc(text));

/// How far from the DAY label (x) its digits may sit.
const double _dayDigitsReach = 0.1;

/// Reads the footer `PART … | DAY 20 여행·교통 140` from the Korean pass.
/// Pages without a footer use the `DAY` header and the `10 …` page line.
PageMeta readPageMeta(OcrScan scan) {
  final ko = scan.korean.lines;
  final jaDay = _firstJaDay(scan.japanese.lines);

  for (final l in stableSorted(ko, (a, b) => cmpNum(-a.cy, -b.cy))) {
    final m = _footer.firstMatch(nfkc(l.text));
    if (m == null) continue;
    // All three groups are mandatory, so a match always fills them.
    final dayToken = m.group(1) ?? '';
    final token = _dayMisreads[dayToken] ?? dayToken;
    return PageMeta(
      day: (isDecimal(token) ? pyInt(token) : null) ?? jaDay,
      title: fixKoreanPeriods(normTitle(m.group(2) ?? '')),
      page: pyInt(m.group(3) ?? ''),
    );
  }

  int? day;
  String? title;
  int? page;
  final dayLabels = ko.where((l) => l.text.trim().toUpperCase() == 'DAY');
  if (dayLabels.isNotEmpty) {
    final d = dayLabels.first;
    final near = ko.where((l) => (l.cy - d.cy).abs() < 0.05);
    // The big DAY digits sit by the label; a word number of the next page
    // (`0017`) on the same height is not the DAY.
    final number = near.where(
      (l) =>
          isDecimal(l.text.trim()) &&
          (l.x - d.x).abs() < _dayDigitsReach &&
          l.text.trim().runes.length <= 2,
    );
    if (number.isNotEmpty) day = int.tryParse(nfkc(number.first.text).trim());
    final heading = near.where((l) => ratio(l.text, isHangul) > 0.5);
    if (heading.isNotEmpty) {
      title = fixKoreanPeriods(normTitle(heading.first.text));
    }
  }
  for (final l in ko) {
    final m = _pageLine.firstMatch(l.text);
    if (m != null && l.cy > 0.9) page = pyInt(m.group(1) ?? '') ?? page;
  }
  return PageMeta(day: day, title: title, page: page);
}

int? _firstJaDay(List<OcrLine> ja) {
  for (final l in ja) {
    final m = _jaDay.firstMatch(nfkc(l.text));
    if (m != null) return pyInt(m.group(1) ?? '');
  }
  return null;
}
