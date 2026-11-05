/// Telling the two layouts apart (rule 1).
///
/// First signal: entry blocks (B) are spaced further apart than list rows (A).
/// It fails when only a few numbers were read: two numbers far apart look like
/// entry blocks. Second signal: example sentences, which only entry pages print.
library;

import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/models/ocr.dart';

enum PageLayout { list, entry }

/// Sentence lines needed to call a page an entry page whatever the number gap.
const int _entrySentences = 3;

/// Shortest example sentence counted, in characters (spaces not counted).
const int _sentenceLength = 10;

/// A sentence in the Japanese pass: long, Japanese, not only kana (furigana),
/// with hiragana (not a list of kanji words).
bool isSentenceLine(OcrLine l) {
  final chars = l.text.runes.where((c) => !isSpace(c)).toList();
  if (chars.length < _sentenceLength) return false;
  final text = String.fromCharCodes(chars);
  return ratio(text, isJp) >= 0.85 &&
      !chars.any(isHangul) &&
      chars.any(isHira) &&
      !kanaOnly(text);
}

/// Which layout [scan] shows.
///
/// No example sentence at all: a list page, even when the few numbers read are
/// far apart. Three or more: an entry page. In between, the number gap decides;
/// with fewer than two numbers the list layout is the default.
PageLayout detectLayout(OcrScan scan) {
  final ja = scan.japanese.lines;
  final sentences = ja.where(isSentenceLine).length;
  if (sentences == 0) return PageLayout.list;
  if (sentences >= _entrySentences) return PageLayout.entry;
  final gap = anchorGap(findAnchors(ja));
  return gap != null && gap > entryLayoutMinGap
      ? PageLayout.entry
      : PageLayout.list;
}
