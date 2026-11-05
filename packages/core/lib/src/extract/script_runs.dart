/// Cutting an OCR line into runs of one script, with estimated positions.
library;

/// Script of a run of characters.
enum Script {
  /// Kana, kanji and Japanese punctuation.
  japanese,

  /// Hangul.
  korean,

  /// Digits only.
  digits,

  /// Latin letters and symbols (checkboxes, ★): OCR garbage on these pages.
  other,
}

/// Part of a line, with its horizontal extent estimated from character widths.
final class ScriptRun {
  const ScriptRun(this.script, this.text, this.start, this.end);

  final Script script;
  final String text;

  /// Fractions of the line's width (0..1).
  final double start;
  final double end;

  @override
  String toString() => '${script.name}:"$text"[$start..$end]';
}

bool isHangul(int c) =>
    (c >= 0xAC00 && c <= 0xD7A3) ||
    (c >= 0x1100 && c <= 0x11FF) ||
    (c >= 0x3130 && c <= 0x318F);

bool isHiragana(int c) => c >= 0x3041 && c <= 0x309F;
bool isKatakana(int c) => (c >= 0x30A1 && c <= 0x30FA) || c == 0x30FC;
bool isKana(int c) => isHiragana(c) || isKatakana(c);

bool isKanji(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0xF900 && c <= 0xFAFF) ||
    c == 0x3005 ||
    c == 0x3006;

/// Japanese punctuation and brackets (full width).
const String japanesePunctuation = '、。「」『』〜～・？！（）［］【】《》〈〉：…';

/// Symbols that are never text on these pages.
const String noiseSymbols = '□■☐☑☒✓✔★☆◆◇●○◎※▲△▼▽♪→←↑↓';

/// ASCII and other punctuation that belongs to whichever script surrounds it.
const String neutralPunctuation = '.,?!()[]:;\'"-/~*·‘’“”`´ˇ%&+=<>_^#@\$';

final Set<int> _jaPunct = japanesePunctuation.runes.toSet();
final Set<int> _noise = noiseSymbols.runes.toSet();
final Set<int> _neutral = neutralPunctuation.runes.toSet();

enum _Cls { ja, ko, digit, other, space, punct }

_Cls _classOf(int c) {
  if (isKana(c) || isKanji(c) || _jaPunct.contains(c)) return _Cls.ja;
  if (isHangul(c)) return _Cls.ko;
  if ((c >= 0x30 && c <= 0x39) || (c >= 0xFF10 && c <= 0xFF19)) {
    return _Cls.digit;
  }
  if (c == 0x20 || c == 0x3000 || c == 0x09) return _Cls.space;
  if (_noise.contains(c)) return _Cls.other;
  if (_neutral.contains(c)) return _Cls.punct;
  return _Cls.other;
}

/// Width of a character relative to a full-width one, for placing runs.
double charWidth(int c) {
  if (c == 0x20 || c == 0x09) return 0.3;
  if (c < 0x80) return 0.55;
  if (c >= 0xFF61 && c <= 0xFF9F) return 0.55; // half-width katakana
  return 1.0;
}

bool _isOpener(int c) => '([（［【「『〈《'.runes.contains(c);

/// [text] cut into runs of one script. Neutral characters (spaces, ASCII
/// punctuation, digits next to letters) join the script around them: the
/// same script on both sides, else the closing ones the run before and the
/// opening ones the run after. Digits on their own make a [Script.digits]
/// run.
List<ScriptRun> scriptRuns(String text) {
  final runes = text.runes.toList();
  if (runes.isEmpty) return const [];
  final cls = [for (final c in runes) _classOf(c)];
  final strong = List<Script?>.filled(runes.length, null);
  for (var i = 0; i < runes.length; i++) {
    strong[i] = switch (cls[i]) {
      _Cls.ja => Script.japanese,
      _Cls.ko => Script.korean,
      _Cls.other => Script.other,
      _ => null,
    };
  }
  final assigned = List<Script?>.of(strong);
  var i = 0;
  while (i < runes.length) {
    if (strong[i] != null) {
      i++;
      continue;
    }
    var j = i;
    while (j < runes.length && strong[j] == null) {
      j++;
    }
    final left = i > 0 ? assigned[i - 1] : null;
    final right = j < runes.length ? strong[j] : null;
    for (var k = i; k < j; k++) {
      assigned[k] = _neutralScript(runes, cls, k, i, j, left, right);
    }
    i = j;
  }
  // Total width, then runs with their extents.
  final widths = [for (final c in runes) charWidth(c)];
  final total = widths.fold(0.0, (s, w) => s + w);
  final out = <ScriptRun>[];
  var pos = 0.0;
  var runStart = 0;
  var runStartPos = 0.0;
  for (var k = 0; k <= runes.length; k++) {
    if (k == runes.length ||
        (k > runStart && assigned[k] != assigned[runStart])) {
      final piece = String.fromCharCodes(runes.sublist(runStart, k));
      final script = assigned[runStart];
      if (script != null && piece.trim().isNotEmpty) {
        // Leading and trailing spaces do not count towards the extent.
        final lead = piece.length - piece.trimLeft().length;
        final trail = piece.length - piece.trimRight().length;
        var s = runStartPos;
        var e = pos;
        for (var t = 0; t < lead; t++) {
          s += widths[runStart + t];
        }
        for (var t = 0; t < trail; t++) {
          e -= widths[k - 1 - t];
        }
        out.add(
          ScriptRun(
            script,
            piece.trim(),
            total == 0 ? 0 : s / total,
            total == 0 ? 1 : e / total,
          ),
        );
      }
      if (k == runes.length) break;
      runStart = k;
      runStartPos = pos;
    }
    pos += widths[k];
  }
  return out;
}

Script? _neutralScript(
  List<int> runes,
  List<_Cls> cls,
  int k,
  int from,
  int to,
  Script? left,
  Script? right,
) {
  final digitsOnly = [
    for (var t = from; t < to; t++) cls[t],
  ].every((c) => c == _Cls.digit || c == _Cls.space);
  final hasSpace = [
    for (var t = from; t < to; t++) cls[t],
  ].contains(_Cls.space);
  // A number on its own, or set off by a space at either end of the line
  // (`3 冷蔵庫`, a word number before the headword).
  if (left == null && right == null ||
      digitsOnly && hasSpace && (left == null || right == null)) {
    return digitsOnly && cls[k] == _Cls.digit ? Script.digits : null;
  }
  if (left == right) return left;
  if (left == null) return right;
  if (right == null) return left;
  // Different scripts on each side: split at the first space, else closers
  // stay left and openers go right.
  final firstSpace = [
    for (var t = from; t < to; t++)
      if (cls[t] == _Cls.space) t,
  ];
  if (firstSpace.isNotEmpty) {
    if (k < firstSpace.first) return left;
    if (k > firstSpace.last) return right;
    // Between the spaces: a number or symbol on its own (`운동 02 料理`).
    if (cls[k] == _Cls.space) return null;
    return cls[k] == _Cls.digit ? Script.digits : Script.other;
  }
  if (digitsOnly) return right;
  return _isOpener(runes[k]) ? right : left;
}
