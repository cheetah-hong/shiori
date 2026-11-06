/// Latin letters in a Korean line that are Japanese read as Latin.
///
/// The Korean pass reads Japanese inside a Korean line as Latin letters and
/// digits (`(~ながら의 꼴로)` may come back as `(~tJh5의 꼴로)`). A run of Latin
/// letters is real when it has the shape real Latin has in Korean text: a
/// site's address, capitals (`JLPT`, `TV를`, `N3`, `T셔츠`), lowercase before
/// a digit (`mp3`), a unit after a number or in brackets (`1kg`, `(kg)`),
/// a hyphenated word (`e-mail`), `e` before Korean (`e메일`), a lone `I`
/// between spaces (a bar `|` read as I). Anything else, and any run right
/// after `~`, is debris (docs/verification.md 26).
///
/// A meaning with debris: the bracket with the debris goes if what is left
/// of its sense is clean Korean; else that sense goes when another sense is
/// clean; else nothing is taken out and the meaning is flagged.
library;

/// Note on a meaning whose debris was taken out (shown as 자동 보정됨).
const String latinDebrisRemovedNote = '영문 찌꺼기 뺌';

/// Note on a meaning whose debris could not be taken out.
const String latinDebrisUnsureNote = '판독 불확실: 영문 찌꺼기';

enum MeaningRepairKind {
  /// A bracket with debris was taken out of a sense.
  trimmed,

  /// A sense with debris was taken out; other senses are clean.
  senseDropped,

  /// Debris left as read: the meaning's only sense, or no sense is clean.
  flagged,
}

/// A meaning after [repairLatinDebris]; [kind] is null when it had no
/// debris.
final class MeaningRepair {
  const MeaningRepair(this.meaning, [this.kind]);

  final String meaning;
  final MeaningRepairKind? kind;
}

/// Units real text writes after a number or in brackets.
const Set<String> latinUnits = {
  'kg',
  'g',
  'mg',
  'km',
  'm',
  'cm',
  'mm',
  'ml',
  'mL',
  'L',
  'l',
  'D',
  'K',
  'GB',
  'MB',
  'KB',
  'Hz',
};

final RegExp _latinRun = RegExp('[A-Za-z]+');
final RegExp _address = RegExp(r'^[A-Za-z0-9]+(\.[A-Za-z0-9]+)+$');
final RegExp _addressName = RegExp('[A-Za-z]{3,}\\.');
final RegExp _hangul = RegExp('[가-힣]');

bool _isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
bool _isLatin(String c) => RegExp('[A-Za-z]').hasMatch(c);
bool _isHangul(String c) => _hangul.hasMatch(c);
bool _isWordChar(String c) => _isLatin(c) || _isDigit(c) || c == '.';

/// Whether [text] has a run of Latin letters that is not real Latin.
bool hasLatinDebris(String text) =>
    _latinRun.allMatches(text).any((m) => _isDebris(text, m.start, m.end));

bool _isDebris(String text, int start, int end) {
  final run = text.substring(start, end);
  final before = start > 0 ? text[start - 1] : ' ';
  final after = end < text.length ? text[end] : ' ';
  if ('~～〜'.contains(before)) return true;
  if (_inAddress(text, start, end)) return false;
  if (_isDigit(before)) return !latinUnits.contains(run);
  if (_hyphenated(text, start, end)) return false;
  if (run.toUpperCase() == run) return false;
  if (run.length == 1 && 'Il'.contains(run) && before == ' ' && after == ' ') {
    return false;
  }
  if (run.length >= 2 && run.toLowerCase() == run && _isDigit(after)) {
    return false;
  }
  if (latinUnits.contains(run) && before == '(' && after == ')') return false;
  if (run == 'e' && (_isHangul(after) || after == '-')) return false;
  return true;
}

/// Part of `name.example.com`.
bool _inAddress(String text, int start, int end) {
  var s = start, e = end;
  while (s > 0 && _isWordChar(text[s - 1])) {
    s--;
  }
  while (e < text.length && _isWordChar(text[e])) {
    e++;
  }
  final word = text.substring(s, e);
  return _address.hasMatch(word) && _addressName.hasMatch(word);
}

/// Part of a hyphenated Latin word (`e-mail`, `Wi-Fi`).
bool _hyphenated(String text, int start, int end) =>
    (end + 1 < text.length && text[end] == '-' && _isLatin(text[end + 1])) ||
    (start >= 2 && text[start - 1] == '-' && _isLatin(text[start - 2]));

/// [meaning] with its debris taken out where that leaves clean Korean
/// (see the library comment); unchanged with a null kind when it has none.
MeaningRepair repairLatinDebris(String meaning) {
  if (!hasLatinDebris(meaning)) return MeaningRepair(meaning);
  final kept = <String>[];
  var dropped = false;
  for (final sense in _senses(meaning)) {
    if (!hasLatinDebris(sense)) {
      kept.add(sense);
      continue;
    }
    final rest = _withoutBracket(sense);
    if (rest != null && _isClean(rest)) {
      kept.add(rest);
    } else {
      dropped = true;
    }
  }
  // Only the senses with debris go, and only when another sense stays.
  if (kept.isEmpty) return MeaningRepair(meaning, MeaningRepairKind.flagged);
  return MeaningRepair(
    _joined(kept),
    dropped ? MeaningRepairKind.senseDropped : MeaningRepairKind.trimmed,
  );
}

/// Senses of a meaning: what `. ` or `; ` closes, the mark kept; a sense
/// number (`1.`) stays with its sense.
List<String> _senses(String meaning) {
  final out = <String>[];
  String? number;
  for (final raw in meaning.split(RegExp(r'(?<=[.;。])\s+'))) {
    final s = raw.trim();
    if (s.isEmpty) continue;
    if (RegExp(r'^\d+[.)]$').hasMatch(s)) {
      number = number == null ? s : '$number $s';
      continue;
    }
    out.add(number == null ? s : '$number $s');
    number = null;
  }
  // A number at the end belongs to the sense before it.
  if (number != null) {
    if (out.isEmpty) return [number];
    out[out.length - 1] = '${out.last} $number';
  }
  return out;
}

String _joined(List<String> senses) => senses
    .join(' ')
    .replaceAllMapped(RegExp(r'\s+([.,;。])'), (m) => m[1]!)
    .replaceAll(RegExp(r'[\s.;。]+$'), '')
    .trim();

/// A sense that is Korean with no debris: two Korean letters or more.
bool _isClean(String sense) =>
    !hasLatinDebris(sense) && _hangul.allMatches(sense).length >= 2;

/// [sense] without the brackets around its debris, each from its `(` to
/// the first `)` that leaves the rest balanced; null when some debris is in
/// no bracket.
String? _withoutBracket(String sense) {
  var s = sense;
  while (true) {
    final debris = _latinRun
        .allMatches(s)
        .where((m) => _isDebris(s, m.start, m.end))
        .firstOrNull;
    if (debris == null) {
      return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    }
    final open = _openBefore(s, debris.start);
    if (open < 0) return null;
    String? cut;
    for (
      var close = s.indexOf(')', debris.end);
      close >= 0;
      close = s.indexOf(')', close + 1)
    ) {
      final rest = s.substring(0, open) + s.substring(close + 1);
      if (_balanced(rest)) {
        cut = rest;
        break;
      }
    }
    if (cut == null) return null;
    s = cut;
  }
}

bool _balanced(String s) {
  var depth = 0;
  for (final c in s.split('')) {
    if (c == '(') depth++;
    if (c == ')' && --depth < 0) return false;
  }
  return depth == 0;
}

/// The `(` still open at [at] in [s] (the bracket around it), or -1.
int _openBefore(String s, int at) {
  var depth = 0;
  for (var i = at - 1; i >= 0; i--) {
    if (s[i] == ')') depth++;
    if (s[i] == '(') {
      if (depth == 0) return i;
      depth--;
    }
  }
  return -1;
}
