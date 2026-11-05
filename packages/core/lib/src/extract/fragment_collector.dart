/// Step 1 of the word extractor: both OCR passes → fragments.
///
/// 1. Every line of both passes is cut into runs of one script
///    ([scriptRuns]), placed by character widths.
/// 2. Japanese is taken from the Japanese pass and Korean from the Korean
///    pass; the other pass's reading of the same place is dropped. Where a
///    Japanese and a Korean run claim one place, the more confident wins
///    (on a tie, Japanese with kana in it).
/// 3. Lines cut off at the photo's edge (the facing page) become noise.
/// 4. Runs are cleaned (checkboxes, POS badges, stray marks) and classified;
///    `漢字(かな)` gives a headword and its reading. Blank-cell dashes, box
///    glyphs, legend and footer lines, and furigana over a sentence are noise.
/// 5. Korean lines that continue the line above and Japanese sentences that
///    wrap are joined.
library;

import 'package:shiori_core/src/capture/text/word_list_marks.dart';
import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/extract/script_runs.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// Lines starting this close to the photo's edge are the facing page.
const double pageEdgeMargin = 0.002;

/// Japanese text this long without sentence punctuation is still a sentence.
const int sentenceLength = 12;

/// Korean text longer than this is a sentence, not a meaning.
const int koreanSentenceLength = 26;

/// A dash alone in a cell at most this share of the page's line height is
/// an empty reading cell (measured: 0.15–0.45; the kanji 一 is as tall as
/// the other words).
const double blankMarkHeight = 0.5;

/// Kana at most this share of a sentence's line height, right above it, are
/// its furigana.
const double furiganaSize = 0.8;

/// Cuts every line of both passes into runs of one script, keeps Japanese
/// from the Japanese pass and Korean from the Korean pass, drops what one
/// pass read twice, and classifies the pieces.
List<Fragment> collectFragments(OcrScan scan) {
  final runs = [
    ..._runsOf(scan.japanese.lines, OcrPass.japanese),
    ..._runsOf(scan.korean.lines, OcrPass.korean),
  ];
  final kept = _resolve(runs);
  final pieces = <_Piece>[];
  final checkboxColumns = _checkboxColumns(kept);
  final lineHeight = _japaneseLineHeight(kept);
  for (final r in kept) {
    pieces.addAll(
      _clean(r, checkboxColumns: checkboxColumns, lineHeight: lineHeight),
    );
  }
  final merged = _joinJapanese(_joinKorean(_markFurigana(pieces)));
  merged.sort(_readingOrder);
  return _number(merged);
}

/// A run placed on the page.
final class _Run {
  _Run(this.run, this.line, this.pass, {required this.edge});

  final ScriptRun run;
  final OcrLine line;
  final OcrPass pass;

  /// The line is cut off at the photo's edge.
  final bool edge;

  double get x0 => line.x + line.width * run.start;
  double get x1 => line.x + line.width * run.end;
  double get y0 => line.y;
  double get y1 => line.y + line.height;
  double get conf => line.confidence;
  Script get script => run.script;
  String get text => run.text;
}

List<_Run> _runsOf(List<OcrLine> lines, OcrPass pass) => [
  for (final l in lines)
    if (l.text.trim().isNotEmpty)
      for (final r in _lineRuns(l.text, pass))
        _Run(
          r,
          l,
          pass,
          edge: l.x <= pageEdgeMargin || l.x + l.width >= 1 - pageEdgeMargin,
        ),
];

/// Runs of a line. In the Korean pass, Japanese between Korean on both sides
/// is part of the Korean text (`(뒤에 する가 붙어) 예약하다`), and a
/// Japanese run is also cut at spaces outside brackets in the Japanese pass
/// (`祖父[そふ] 圭仕`: the second part is that pass reading Korean).
List<ScriptRun> _lineRuns(String text, OcrPass pass) {
  final runs = scriptRuns(text);
  if (pass == OcrPass.japanese) {
    return [for (final r in runs) ..._splitAtSpaces(r)];
  }
  // Korean pass: whatever lies between two Korean runs (its reading of
  // Japanese, Latin garbage) is part of the Korean text.
  final out = <ScriptRun>[];
  for (final r in runs) {
    if (r.script == Script.korean && out.isNotEmpty) {
      final lastKorean = out.lastIndexWhere((x) => x.script == Script.korean);
      if (lastKorean >= 0 && lastKorean < out.length - 1) {
        final first = out[lastKorean];
        out
          ..removeRange(lastKorean, out.length)
          ..add(
            ScriptRun(
              Script.korean,
              _between(text, first, r),
              first.start,
              r.end,
            ),
          );
        continue;
      }
      if (lastKorean == out.length - 1) {
        final first = out.removeLast();
        out.add(
          ScriptRun(
            Script.korean,
            _between(text, first, r),
            first.start,
            r.end,
          ),
        );
        continue;
      }
    }
    out.add(r);
  }
  return out;
}

/// The text of [text] from [a]'s start to [b]'s end.
String _between(String text, ScriptRun a, ScriptRun b) {
  final from = text.indexOf(a.text);
  final to = text.indexOf(b.text, from < 0 ? 0 : from + a.text.length);
  if (from < 0 || to < 0) return '${a.text} ${b.text}';
  return text.substring(from, to + b.text.length);
}

final RegExp _spaceOutsideBrackets = RegExp(r'\s+(?![^(（\[［【「]*[)）\]］】」])');

List<ScriptRun> _splitAtSpaces(ScriptRun r) {
  if (r.script != Script.japanese || !r.text.contains(RegExp(r'\s'))) {
    return [r];
  }
  final parts = r.text.split(_spaceOutsideBrackets);
  if (parts.length == 1) return [r];
  final total = r.text.runes.fold(0.0, (s, c) => s + charWidth(c));
  final span = r.end - r.start;
  final out = <ScriptRun>[];
  var pos = 0;
  for (final part in parts) {
    final at = r.text.indexOf(part, pos);
    final before = r.text
        .substring(0, at)
        .runes
        .fold(0.0, (s, c) => s + charWidth(c));
    final width = part.runes.fold(0.0, (s, c) => s + charWidth(c));
    out.add(
      ScriptRun(
        Script.japanese,
        part,
        r.start + span * before / total,
        r.start + span * (before + width) / total,
      ),
    );
    pos = at + part.length;
  }
  return out;
}

bool _overlaps(_Run a, _Run b) {
  final h = (a.y1 < b.y1 ? a.y1 : b.y1) - (a.y0 > b.y0 ? a.y0 : b.y0);
  final minH = (a.y1 - a.y0) < (b.y1 - b.y0) ? a.y1 - a.y0 : b.y1 - b.y0;
  if (minH <= 0 || h < 0.5 * minH) return false;
  final w = (a.x1 < b.x1 ? a.x1 : b.x1) - (a.x0 > b.x0 ? a.x0 : b.x0);
  final minW = (a.x1 - a.x0) < (b.x1 - b.x0) ? a.x1 - a.x0 : b.x1 - b.x0;
  if (minW <= 0) return w > 0;
  return w >= 0.4 * minW;
}

int _kanaCount(String s) => s.runes.where(isKana).length;

int _hangulCount(String s) => s.runes.where(isHangul).length;

/// Median height of the Japanese pass's lines of two letters or more (the
/// page's type size), or null when there is none.
double? _japaneseLineHeight(List<_Run> runs) {
  final heights = [
    for (final r in runs)
      if (r.pass == OcrPass.japanese &&
          r.script == Script.japanese &&
          _letters(r.text) >= 2)
        r.y1 - r.y0,
  ]..sort();
  return heights.isEmpty ? null : heights[heights.length ~/ 2];
}

String _letterText(String s) => String.fromCharCodes(
  s.runes.where((c) => isKana(c) || isKanji(c) || isHangul(c)),
);

int _letters(String s) =>
    s.runes.where((c) => isKana(c) || isKanji(c) || isHangul(c)).length;

/// Which runs survive: each script from the pass that reads it, one run per
/// place.
List<_Run> _resolve(List<_Run> runs) {
  final ja = runs.where((r) => r.pass == OcrPass.japanese).toList();
  final ko = runs.where((r) => r.pass == OcrPass.korean).toList();
  final koKorean = ko.where((r) => r.script == Script.korean).toList();
  final kept = <_Run>[];
  for (final r in ja) {
    if (r.script == Script.korean && koKorean.any((k) => _overlaps(r, k))) {
      continue; // Korean is read by the Korean pass
    }
    if (r.script != Script.korean && r.script != Script.japanese) {
      if (koKorean.any((k) => _overlaps(r, k))) continue; // garbage over Korean
    }
    kept.add(r);
  }
  for (final r in ko) {
    if (r.script != Script.korean && ja.any((j) => _overlaps(r, j))) {
      continue; // the Japanese pass read this place
    }
    kept.add(r);
  }
  // A Japanese run and a Korean run on one place: keep one.
  final dropped = <_Run>{};
  for (final j in kept.where((r) => r.script == Script.japanese)) {
    for (final k in kept.where((r) => r.script == Script.korean)) {
      if (j.pass == k.pass || !_overlaps(j, k)) continue;
      // The Korean pass kept this Japanese inside its Korean text.
      if (_letters(j.text) >= 2 &&
          _letterText(k.text).contains(_letterText(j.text))) {
        continue;
      }
      // A meaning line with its POS badge in front is Korean, whatever the
      // Japanese pass made of it (`8叉` at full confidence over `명 창문`).
      if (_badgeLine.hasMatch(k.text.trim())) {
        dropped.add(j);
        continue;
      }
      // One Korean syllable over Japanese: the Korean pass reading a
      // headword or a reading as garbage (`트`, `(다`). Over kana it loses;
      // over one kanji both stay and the dictionary decides.
      if (_hangulCount(k.text) <= 1 && !_posBadgeOnly(k.text)) {
        if (_kanaCount(j.text) >= 2) {
          dropped.add(k);
          continue;
        }
        if (_letters(j.text) == 1) continue;
      }
      // The Japanese pass's lowest confidence over Korean text: garbage.
      if (atLowestConfidence(j.conf) && k.conf > j.conf) {
        dropped.add(j);
        continue;
      }
      if (_mixedLine(j, k, runs)) {
        // On a mixed line a kanji-only piece over Korean is the Japanese
        // pass reading the Korean part.
        if (_kanaCount(j.text) == 0) dropped.add(j);
        continue;
      }
      final japaneseWins =
          j.conf > k.conf ||
          (j.conf == k.conf &&
              (_kanaCount(j.text) >= 1 && _letters(j.text) >= 2 ||
                  _letters(k.text) <= 1));
      dropped.add(japaneseWins ? k : j);
    }
  }
  return [
    for (final r in kept)
      if (!dropped.contains(r)) r,
  ];
}

/// Both passes read one mixed line (each with the other script garbled):
/// the Japanese of one and the Korean of the other are both real text.
bool _mixedLine(_Run j, _Run k, List<_Run> runs) {
  if (_boxOverlap(j.line, k.line) < 0.7) return false;
  int pieces(OcrLine line) => runs.where((r) => identical(r.line, line)).length;
  return pieces(j.line) >= 2 && pieces(k.line) >= 2;
}

double _boxOverlap(OcrLine a, OcrLine b) {
  final w =
      (a.x + a.width < b.x + b.width ? a.x + a.width : b.x + b.width) -
      (a.x > b.x ? a.x : b.x);
  final h =
      (a.y + a.height < b.y + b.height ? a.y + a.height : b.y + b.height) -
      (a.y > b.y ? a.y : b.y);
  if (w <= 0 || h <= 0) return 0;
  final inter = w * h;
  return inter / (a.width * a.height + b.width * b.height - inter);
}

/// A cleaned piece before it gets its id.
final class _Piece {
  _Piece({
    required this.text,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pass,
    required this.confidence,
    this.readingOf,
    this.notes = const [],
    this.corrected = false,
    this.droppedPrefix,
    this.posBadge,
  });

  final String text;
  final FragmentKind kind;
  final double x;
  final double y;
  final double width;
  final double height;
  final OcrPass pass;
  final double confidence;

  /// For an inline reading: the headword piece.
  _Piece? readingOf;
  final List<String> notes;
  final bool corrected;
  final String? droppedPrefix;
  final String? posBadge;

  double get cy => y + height / 2;
  double get right => x + width;
  double get bottom => y + height;

  _Piece copy({
    String? text,
    FragmentKind? kind,
    double? x,
    double? y,
    double? width,
    double? height,
    double? confidence,
    List<String>? notes,
    bool? corrected,
    String? droppedPrefix,
    String? posBadge,
  }) => _Piece(
    text: text ?? this.text,
    kind: kind ?? this.kind,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    pass: pass,
    confidence: confidence ?? this.confidence,
    readingOf: readingOf,
    notes: notes ?? this.notes,
    corrected: corrected ?? this.corrected,
    droppedPrefix: droppedPrefix ?? this.droppedPrefix,
    posBadge: posBadge ?? this.posBadge,
  );
}

const String _checkboxGlyphs = '□■☐☑☒口ロ';

/// Glyphs OCR reads for a row of checkboxes (also the dash after them).
final Set<int> _boxRowGlyphs = '□■☐☑☒口ロコー'.runes.toSet();

/// Kanji OCR reads for a lone checkbox.
const Set<String> _boxKanji = {'問', '目'};
final RegExp _leadingCheckbox = RegExp('^[□■☐☑☒|｜]+\\s*');
final RegExp _leadingLookalikeBox = RegExp('^[口ロ](?:\\s+|(?=[^\\s]))');

/// Where the checkbox columns are: three or more Japanese runs whose left
/// edges line up (within a line height) start with a box glyph; each such
/// group is a column at its median x. Empty when the page has none.
/// A box printed on its own (`□`, read apart from the word after it).
bool _onlyBoxes(String text) {
  final t = text.trim();
  return t.isNotEmpty && t.runes.every(_printedBoxes.contains);
}

final Set<int> _printedBoxes = '□■☐☑☒'.runes.toSet();

/// Width of one full-width glyph of [text] set in [width] (page-width units).
double _em(double width, String text) {
  final units = text.runes.fold(0.0, (n, c) => n + charWidth(c));
  return width / (units < 1 ? 1 : units);
}

List<double> _checkboxColumns(List<_Run> runs) {
  final boxed = [
    for (final r in runs)
      if (r.script == Script.japanese &&
              r.text.length > 1 &&
              _checkboxGlyphs.contains(r.text[0]) ||
          _onlyBoxes(r.text))
        r,
  ]..sort((a, b) => a.x0.compareTo(b.x0));
  final columns = <double>[];
  var group = <_Run>[];
  void close() {
    if (group.length >= 3) columns.add(group[group.length ~/ 2].x0);
    group = [];
  }

  for (final r in boxed) {
    if (group.isNotEmpty && r.x0 - group.last.x0 > _em(r.x1 - r.x0, r.text)) {
      close();
    }
    group.add(r);
  }
  close();
  return columns;
}

final RegExp _inlineReading = RegExp(
  r'^([\p{Script=Han}々〆][\p{Script=Han}々〆\p{Script=Hiragana}\p{Script=Katakana}ー]*?)\s*'
  r'[(（\[［【「]\s*([\p{Script=Hiragana}\p{Script=Katakana}ー\s/／・]+?)\s*[)）\]］】」]?\s*$',
  unicode: true,
);

/// `学校がっこう］`: the opening bracket was not read.
final RegExp _inlineReadingNoOpen = RegExp(
  r'^([\p{Script=Han}々〆]+)([\p{Script=Hiragana}ー]{2,})[)）\]］】」]$',
  unicode: true,
);

final RegExp _japaneseSentenceMark = RegExp('[。？！?!、〜～]');
final RegExp _digitsOnly = RegExp(r'^[0-9０-９\s.,:/-]+$');

/// Parts of speech spelled out as a badge (`동사 열다`).
const Set<String> _spelledBadges = {'명사', '동사', '형용사', '부사'};

final String _badges = badgeAlternation({...posBadges.keys, ..._spelledBadges});

/// The POS badge word lists print before a meaning, as OCR reads them
/// (shared with the row templates), maybe in brackets.
final RegExp _posBadge = RegExp('^\\[?($_badges)\\]?$badgeSeparator');

/// The badge [read] is, spelled-out names folded to the badge.
String? _badgeOf(String read) =>
    posBadges[read] ??
    const {'명사': '명', '동사': '동', '형용사': '형', '부사': '부'}[read];

/// A badge, then the Korean meaning (maybe after a number: `명 3, 셋`).
final RegExp _badgeLine = RegExp(
  '^\\[?(?:$_badges)\\]?\\s*[.:·]?\\s+[0-9,.\\s]*[가-힣]',
);

final RegExp _badgeAlone = RegExp('^\\[?(?:$_badges)\\]?\$');

bool _posBadgeOnly(String text) => _badgeAlone.hasMatch(text.trim());

/// Korean lines that label rather than mean: a legend (`* 표시 = …`), a
/// footer (`단어 | DAY 10`), a box heading (`[문형] …`).
final RegExp _markerLine = RegExp(r'[=|｜]|^\s*[\[［【〈<]');

final RegExp _strayMarks = RegExp('^[\'‘’`´ˇ✓✔,.]+|[\'‘’`´ˇ✓✔]+\$');
final RegExp _leadingNote = RegExp(r'^\(([^()]*)\)\s*');
final RegExp _trailingNote = RegExp(r'\s*\(([^()]*)\)$');
final RegExp _supplement = RegExp(r'\s+\*\s*(.+)$');
final RegExp _koreanSentenceEnd = RegExp(r'[.?!。？！][)"\x27’”]*$');

List<_Piece> _clean(
  _Run r, {
  required List<double> checkboxColumns,
  double? lineHeight,
}) {
  final base = _Piece(
    text: r.text,
    kind: FragmentKind.noise,
    x: r.x0,
    y: r.y0,
    width: r.x1 - r.x0,
    height: r.y1 - r.y0,
    pass: r.pass,
    confidence: r.conf,
  );
  if (r.edge) return [base];
  return switch (r.script) {
    Script.japanese => _cleanJapanese(
      base,
      checkboxColumns: checkboxColumns,
      lineHeight: lineHeight,
    ),
    Script.korean => [_cleanKorean(base)],
    Script.digits => [base.copy(kind: FragmentKind.number)],
    Script.other => [base],
  };
}

List<_Piece> _cleanJapanese(
  _Piece p, {
  required List<double> checkboxColumns,
  double? lineHeight,
}) {
  var text = p.text;
  var corrected = false;
  // A dash alone in a cell, much lower than the page's type: an empty
  // reading cell, not the kanji 一 or the long vowel mark.
  if (lineHeight != null &&
      blankCellMarks.contains(text.trim()) &&
      p.height <= blankMarkHeight * lineHeight) {
    return [p.copy(kind: FragmentKind.noise, corrected: true)];
  }
  final box = _leadingCheckbox.firstMatch(text);
  if (box != null) {
    text = text.substring(box.end);
    corrected = true;
  }
  if (text.isNotEmpty &&
      text.runes.every((c) => _checkboxGlyphs.runes.contains(c))) {
    return [p.copy(kind: FragmentKind.noise)];
  }
  // Within one glyph of the column: the glyph width is measured along the
  // line (x), so a tall or wide photo gives the same tolerance.
  final atColumn = checkboxColumns.any(
    (c) => (p.x - c).abs() <= _em(p.width, p.text),
  );
  // A row of boxes read as box-like glyphs (`コロロ`, `ロロー`), or one box
  // read as a kanji (`問`), where the boxes are or at the lowest confidence.
  final bare = text.replaceAll(RegExp(r'\s'), '');
  final boxes = bare.runes.where(
    (c) => _boxRowGlyphs.contains(c) && c != 0x30FC,
  );
  if ((atColumn || atLowestConfidence(p.confidence)) &&
      bare.isNotEmpty &&
      bare.runes.every(_boxRowGlyphs.contains) &&
      boxes.length >= 2) {
    return [p.copy(kind: FragmentKind.noise, corrected: true)];
  }
  if (atColumn && _boxKanji.contains(bare)) {
    return [p.copy(kind: FragmentKind.noise, corrected: true)];
  }
  // A 口 or ロ at the checkbox column's x (or set off by a space) is a box.
  final lookalike = _leadingLookalikeBox.firstMatch(text);
  String? droppedPrefix;
  if (lookalike != null &&
      text.length > 1 &&
      (atColumn ||
          lookalike.group(0)!.trim().length < lookalike.group(0)!.length)) {
    droppedPrefix = lookalike.group(0)!.trim();
    text = text.substring(lookalike.end);
    corrected = true;
  }
  text = text.trim();
  if (text.isEmpty) return [p.copy(kind: FragmentKind.noise)];
  // Move the box past the characters taken off the front.
  final removed = corrected ? p.text.indexOf(text).clamp(0, p.text.length) : 0;
  final perChar = p.width / (p.text.isEmpty ? 1 : p.text.length);
  final shifted = p.copy(
    text: text,
    x: p.x + perChar * removed,
    width: p.width - perChar * removed,
    corrected: corrected,
    droppedPrefix: droppedPrefix,
  );
  return _splitInlineReading(shifted);
}

List<_Piece> _splitInlineReading(_Piece p) {
  final m =
      _inlineReading.firstMatch(p.text) ??
      _inlineReadingNoOpen.firstMatch(p.text);
  if (m == null) return [p.copy(kind: _japaneseKind(p.text))];
  final head = m.group(1)!;
  final reading = m.group(2)!.replaceAll(RegExp(r'\s'), '');
  if (reading.isEmpty) return [p.copy(kind: _japaneseKind(p.text))];
  final perChar = p.width / p.text.length;
  final headPiece = p.copy(
    text: head,
    kind: FragmentKind.kanjiWord,
    width: perChar * head.length,
  );
  final readingStart = p.text.indexOf(m.group(2)!.trimLeft());
  final readingPiece = p.copy(
    text: reading,
    kind: FragmentKind.kana,
    x: p.x + perChar * readingStart,
    width: perChar * m.group(2)!.trim().length,
    corrected: p.corrected || reading != m.group(2),
  )..readingOf = headPiece;
  return [headPiece, readingPiece];
}

FragmentKind _japaneseKind(String text) {
  if (_digitsOnly.hasMatch(text)) return FragmentKind.number;
  final letters = text.runes.where((c) => isKana(c) || isKanji(c)).length;
  if (letters == 0) return FragmentKind.noise;
  if (_japaneseSentenceMark.hasMatch(text) || letters >= sentenceLength) {
    return FragmentKind.japaneseSentence;
  }
  if (text.runes.any(isKanji)) return FragmentKind.kanjiWord;
  return FragmentKind.kana;
}

_Piece _cleanKorean(_Piece p) {
  var text = p.text;
  var corrected = false;
  final notes = <String>[];
  final badge = _posBadge.firstMatch(text);
  if (badge != null) {
    text = text.substring(badge.end);
    corrected = true;
  }
  final posBadge = badge == null ? p.posBadge : _badgeOf(badge.group(1)!);
  final stray = text.replaceAll(_strayMarks, '').trim();
  if (stray != text.trim()) corrected = true;
  text = stray;
  if (text.isEmpty) return p.copy(kind: FragmentKind.noise, corrected: true);
  if (_markerLine.hasMatch(text)) return p.copy(kind: FragmentKind.noise);
  final sentence =
      _koreanSentenceEnd.hasMatch(text) ||
      text.runes.where(isHangul).length > koreanSentenceLength;
  if (!sentence) {
    final supplement = _supplement.firstMatch(text);
    if (supplement != null) {
      notes.add(supplement.group(1)!.trim());
      text = text.substring(0, supplement.start).trim();
    }
    final lead = _leadingNote.firstMatch(text);
    if (lead != null && lead.end < text.length) {
      notes.add(lead.group(1)!.trim());
      text = text.substring(lead.end).trim();
    }
    final trail = _trailingNote.firstMatch(text);
    if (trail != null && trail.start > 0) {
      notes.add(trail.group(1)!.trim());
      text = text.substring(0, trail.start).trim();
    }
  }
  return p.copy(
    text: text,
    kind: sentence ? FragmentKind.koreanSentence : FragmentKind.hangul,
    notes: notes,
    corrected: corrected,
    posBadge: posBadge,
  );
}

/// Furigana over a sentence's kanji: kana well below the sentence's size,
/// right above it and inside its width, with no headword to their left on
/// their row (whose reading they would be). They are the readings the
/// sentence prints, not words of their own.
List<_Piece> _markFurigana(List<_Piece> pieces) {
  final sentences = [
    for (final p in pieces)
      if (p.pass == OcrPass.japanese && p.kind == FragmentKind.japaneseSentence)
        p,
  ];
  final headwords = [
    for (final p in pieces)
      if (p.pass == OcrPass.japanese && p.kind == FragmentKind.kanjiWord) p,
  ];
  // A kanji word to the left on the row: the kana is its reading.
  bool readsHeadword(_Piece k) =>
      headwords.any((h) => h.right <= k.x + 0.5 * k.height && _sameRow(h, k));
  bool over(_Piece k, _Piece s) {
    final gap = s.y - k.bottom;
    final cx = k.x + k.width / 2;
    return k.height <= furiganaSize * s.height &&
        gap >= -0.4 * s.height &&
        gap <= 0.8 * s.height &&
        cx >= s.x &&
        cx <= s.right;
  }

  return [
    for (final p in pieces)
      if (p.pass == OcrPass.japanese &&
          p.kind == FragmentKind.kana &&
          p.readingOf == null &&
          sentences.any((s) => over(p, s)) &&
          !readsHeadword(p))
        p.copy(kind: FragmentKind.noise, corrected: true)
      else
        p,
  ];
}

bool _sameRow(_Piece a, _Piece b) {
  final h = a.height < b.height ? a.height : b.height;
  return (a.cy - b.cy).abs() < 0.5 * h;
}

/// A Korean line right under another, starting at the same x, with no
/// Japanese on its own row to the left: the meaning or paragraph above it
/// went on to the next line (`고르다, 여럿 가운데서` / `가려 뽑다`).
List<_Piece> _joinKorean(List<_Piece> pieces) {
  final korean =
      pieces
          .where(
            (p) =>
                p.kind == FragmentKind.hangul ||
                p.kind == FragmentKind.koreanSentence,
          )
          .toList()
        ..sort(_readingOrder);
  final japanese = pieces
      .where(
        (p) =>
            p.kind == FragmentKind.kanjiWord ||
            p.kind == FragmentKind.kana ||
            p.kind == FragmentKind.japaneseSentence,
      )
      .toList();
  final absorbed = <_Piece>{};
  final replaced = <_Piece, _Piece>{};
  for (final upper in korean) {
    if (absorbed.contains(upper)) continue;
    var current = replaced[upper] ?? upper;
    for (final lower in korean) {
      if (lower == upper || absorbed.contains(lower)) continue;
      if (!_continues(current, lower, japanese)) continue;
      current = _joined(current, lower);
      absorbed.add(lower);
    }
    replaced[upper] = current;
  }
  return [
    for (final p in pieces)
      if (!absorbed.contains(p)) replaced[p] ?? p,
  ];
}

bool _continues(_Piece upper, _Piece lower, List<_Piece> japanese) {
  final h = upper.height < lower.height ? upper.height : lower.height;
  final gap = lower.y - upper.bottom;
  if (gap < -0.3 * h || gap > 1.2 * h) return false;
  if ((lower.x - upper.x).abs() > 1.5 * h) return false;
  if (_koreanSentenceEnd.hasMatch(upper.text)) return false;
  // A headword beside the lower line starts a new item.
  return !japanese.any(
    (j) => j.x < lower.x && j.y < lower.bottom && j.bottom > lower.y,
  );
}

_Piece _joined(_Piece a, _Piece b) {
  final glue =
      RegExp(r'[가-힣]$').hasMatch(a.text) && RegExp(r'^[가-힣]').hasMatch(b.text)
      ? ''
      : ' ';
  final right = a.right > b.right ? a.right : b.right;
  final cleaned = _cleanKorean(
    a.copy(
      text: '${a.text}$glue${b.text}'.trim(),
      width: right - a.x,
      height: b.bottom - a.y,
      confidence: a.confidence < b.confidence ? a.confidence : b.confidence,
      notes: const [],
    ),
  );
  return cleaned.copy(
    notes: [...a.notes, ...b.notes, ...cleaned.notes],
    corrected: true,
  );
}

/// Japanese pieces of one row that touch (`はい、` + `～ました。`), and a
/// sentence that wraps onto the next line at the same x.
List<_Piece> _joinJapanese(List<_Piece> pieces) {
  final sentences =
      pieces
          .where(
            (p) =>
                p.pass == OcrPass.japanese &&
                (p.kind == FragmentKind.japaneseSentence ||
                    p.kind == FragmentKind.kana ||
                    p.kind == FragmentKind.kanjiWord) &&
                p.readingOf == null &&
                !pieces.any((q) => q.readingOf == p),
          )
          .toList()
        ..sort(_readingOrder);
  final absorbed = <_Piece>{};
  final replaced = <_Piece, _Piece>{};
  for (final a in sentences) {
    if (absorbed.contains(a)) continue;
    var current = replaced[a] ?? a;
    for (final b in sentences) {
      if (b == a || absorbed.contains(b)) continue;
      if (!_touchOnRow(current, b) && !_wraps(current, b)) continue;
      final text = current.text + b.text;
      current = current.copy(
        text: text,
        kind: FragmentKind.japaneseSentence,
        width: (b.right > current.right ? b.right : current.right) - current.x,
        height:
            (b.bottom > current.bottom ? b.bottom : current.bottom) - current.y,
        confidence: current.confidence < b.confidence
            ? current.confidence
            : b.confidence,
        corrected: true,
      );
      absorbed.add(b);
    }
    replaced[a] = current;
  }
  return [
    for (final p in pieces)
      if (!absorbed.contains(p)) replaced[p] ?? p,
  ];
}

bool _isSentenceLike(_Piece p) =>
    p.kind == FragmentKind.japaneseSentence || RegExp('[、〜～]').hasMatch(p.text);

bool _touchOnRow(_Piece a, _Piece b) {
  if (!_sameRow(a, b) || b.x < a.x) return false;
  final h = a.height < b.height ? a.height : b.height;
  final gap = b.x - a.right;
  return gap < 0.8 * h &&
      gap > -1.0 * h &&
      (_isSentenceLike(a) || _isSentenceLike(b));
}

bool _wraps(_Piece a, _Piece b) {
  if (a.kind != FragmentKind.japaneseSentence) return false;
  if (RegExp('[。？！?!]\$').hasMatch(a.text)) return false;
  final h = a.height < b.height ? a.height : b.height;
  final gap = b.y - a.bottom;
  return gap >= -0.3 * h &&
      gap < 0.8 * h &&
      (b.x - a.x).abs() < 1.5 * h &&
      b.width < a.width;
}

int _readingOrder(_Piece a, _Piece b) {
  final h = a.height < b.height ? a.height : b.height;
  if ((a.cy - b.cy).abs() >= 0.5 * h) return a.cy.compareTo(b.cy);
  return a.x.compareTo(b.x);
}

List<Fragment> _number(List<_Piece> pieces) {
  final ids = {for (final (i, p) in pieces.indexed) p: i};
  return [
    for (final (i, p) in pieces.indexed)
      Fragment(
        id: i,
        text: p.text,
        kind: p.kind,
        x: p.x,
        y: p.y,
        width: p.width,
        height: p.height,
        pass: p.pass,
        confidence: p.confidence,
        inlineReadingOf: p.readingOf == null ? null : ids[p.readingOf],
        notes: p.notes,
        corrected: p.corrected,
        droppedPrefix: p.droppedPrefix,
        posBadge: p.posBadge,
      ),
  ];
}
