/// The Korean pass's word boxes of one line joined again, before the word
/// extractor cuts lines into runs (docs/extraction.md 2).
///
/// An engine that boxes each word (ML Kit's elements) gives a meaning line
/// `9, 아홉` as `9,` and `아홉`: the bare `아홉` then pairs as the meaning on its
/// own. Boxes that touch on one line are one line again; a box that is only
/// a POS badge or only a number stays its own cell, as do text set sideways
/// (a page read on its side) and anything with Japanese in it.
library;

import 'package:shiori_core/src/capture/text/word_list_marks.dart';
import 'package:shiori_core/src/extract/script_runs.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// Widest gap between two boxes of one line, in line heights (measured:
/// 0.4–0.8 between ML Kit's word boxes).
const double touchingGap = 0.8;

/// Boxes overlapping by more than this share of the line height are no
/// neighbours.
const double _overlap = 0.2;

/// Two boxes on one line are at least this alike in height.
const double _heightRatio = 0.6;

/// Two boxes on one line have their centres at most this share of the
/// line height apart.
const double _centreOffset = 0.3;

/// A box narrower than this share of its text laid across (character
/// widths × height) is text set sideways.
const double sidewaysShare = 0.4;

/// Korean text, digits, spaces and the punctuation of a meaning line.
final RegExp _koreanText = RegExp(r'^[가-힣ㄱ-ㆎ0-9０-９\s,.，．、()（）~～\-/·]+$');

final RegExp _onlyNumber = RegExp(r'^[0-9０-９]+$');

final String _badges = badgeAlternation(posBadges.keys);

/// A box that is only a badge (`명`).
final RegExp _onlyBadge = RegExp('^(?:$_badges)\$');

/// A box that starts with a badge (`명 9, 구`): a new cell.
final RegExp _startsWithBadge = RegExp('^(?:$_badges)$badgeSeparator');

bool _hasHangul(String s) => s.runes.any((c) => c >= 0xAC00 && c <= 0xD7A3);

/// [l] can join a neighbour: Korean text set across, not a badge or a
/// number alone.
bool _joinable(OcrLine l) {
  final t = l.text.trim();
  if (!_koreanText.hasMatch(t)) return false;
  if (_onlyBadge.hasMatch(t) || _onlyNumber.hasMatch(t)) return false;
  final across = t.runes.fold(0.0, (s, c) => s + charWidth(c));
  return l.width >= sidewaysShare * across * l.height;
}

/// [right] continues [left] on its line.
bool _continues(OcrLine left, OcrLine right) {
  if (_startsWithBadge.hasMatch(right.text.trim())) return false;
  if (!_hasHangul(left.text) && !_hasHangul(right.text)) return false;
  final high = left.height > right.height ? left.height : right.height;
  final low = left.height < right.height ? left.height : right.height;
  if (low < high * _heightRatio) return false;
  if ((left.cy - right.cy).abs() > high * _centreOffset) return false;
  final gap = right.x - (left.x + left.width);
  return gap >= -_overlap * high && gap <= touchingGap * high;
}

/// [left] and [right] as one line: the texts with a space, the box around
/// both, the lower confidence.
OcrLine _joined(OcrLine left, OcrLine right) {
  final x1 = [
    left.x + left.width,
    right.x + right.width,
  ].reduce((a, b) => a > b ? a : b);
  final y0 = left.y < right.y ? left.y : right.y;
  final y1 = [
    left.y + left.height,
    right.y + right.height,
  ].reduce((a, b) => a > b ? a : b);
  return OcrLine(
    text: '${left.text.trimRight()} ${right.text.trimLeft()}',
    x: left.x,
    y: y0,
    width: x1 - left.x,
    height: y1 - y0,
    confidence: left.confidence < right.confidence
        ? left.confidence
        : right.confidence,
  );
}

/// [lines] (a Korean pass) with the boxes of one line that touch joined,
/// left to right; [lines] itself when nothing joins.
List<OcrLine> joinTouchingKorean(List<OcrLine> lines) {
  final byX = [...lines]..sort((a, b) => a.x.compareTo(b.x));
  final taken = List<bool>.filled(byX.length, false);
  final out = <OcrLine>[];
  var joinedAny = false;
  for (var i = 0; i < byX.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    var line = byX[i];
    if (_joinable(line)) {
      for (var next = _nextOf(line, byX, taken); next != null;) {
        taken[next] = true;
        line = _joined(line, byX[next]);
        joinedAny = true;
        next = _nextOf(line, byX, taken);
      }
    }
    out.add(line);
  }
  return joinedAny ? List.unmodifiable(out) : lines;
}

/// The index of the box in [byX] nearest to the right that continues
/// [line], among those not [taken]; null when none does.
int? _nextOf(OcrLine line, List<OcrLine> byX, List<bool> taken) {
  int? best;
  for (var j = 0; j < byX.length; j++) {
    if (taken[j] || !_joinable(byX[j]) || !_continues(line, byX[j])) continue;
    if (best == null || byX[j].x < byX[best].x) best = j;
  }
  return best;
}
