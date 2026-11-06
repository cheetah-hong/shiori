/// Headwords OCR split or misread, mended by content before pairing:
/// two kanji words a space cut apart (`交通 事故`) and a kana-only headword
/// with a look-alike glyph (`ニつ` for `二つ`), each only when the dictionary
/// has the mended word and a kana reading on the same row reads it.
/// Also the forms of a headword printed with an optional prefix in brackets
/// (`(お)みやげ`).
library;

import 'package:shiori_core/src/capture/correctors/confusables.dart';
import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/extract/script_runs.dart';

/// Whether the dictionary reads [headword] as [kana].
typedef ReadsAs = bool Function(String headword, String kana);

/// A mended fragment and why it differs from what OCR read.
typedef Mend = ({Fragment fragment, String note});

/// Katakana that look like hiragana (the same strokes).
final Map<int, int> _hiraganaTwins = {
  for (final (k, h) in [('ヘ', 'へ'), ('ベ', 'べ'), ('ペ', 'ぺ')])
    k.runes.single: h.runes.single,
};

/// [text] (kana only) with each look-alike katakana swapped for its kanji or
/// hiragana twin, fewest changes first; only spellings with a kanji in them
/// (`ニつ` → `二つ`). Katakana inside a katakana word stays (`カメラ`).
List<String> kanaLookalikeVariants(String text) {
  final runes = text.runes.toList();
  if (runes.any(isKanji) || !runes.any(isKatakana)) return const [];
  int? swap(int c) => confusableInKanji[c] ?? _hiraganaTwins[c];
  bool lone(int i) =>
      (i == 0 || !isKatakana(runes[i - 1]) || swap(runes[i - 1]) != null) &&
      (i == runes.length - 1 ||
          !isKatakana(runes[i + 1]) ||
          swap(runes[i + 1]) != null);
  final spots = [
    for (var i = 0; i < runes.length; i++)
      if (swap(runes[i]) != null && lone(i)) i,
  ];
  if (spots.isEmpty || spots.length > _maxSwaps) return const [];
  final out = <List<int>>[];
  for (var mask = 1; mask < 1 << spots.length; mask++) {
    final v = [...runes];
    for (var b = 0; b < spots.length; b++) {
      if (mask & (1 << b) != 0) v[spots[b]] = swap(runes[spots[b]])!;
    }
    if (v.any(isKanji)) out.add(v);
  }
  int changes(List<int> v) => [
    for (var i = 0; i < v.length; i++) v[i] != runes[i],
  ].where((c) => c).length;
  out.sort((a, b) => changes(a).compareTo(changes(b)));
  return [for (final v in out) String.fromCharCodes(v)];
}

const int _maxSwaps = 3;

/// `(お)みやげ` → [`おみやげ`, `みやげ`]: the word with and without the
/// optional prefix in brackets; empty when [text] has none.
List<String> optionalPrefixForms(String text) {
  final m = _optionalPrefix.firstMatch(text.trim());
  if (m == null) return const [];
  return [m.group(1)! + m.group(2)!, m.group(2)!];
}

final RegExp _optionalPrefix = RegExp(r'^[(（]([^()（）]{1,2})[)）](.+)$');

bool _sameRow(Fragment a, Fragment b, double rows) =>
    (a.cy - b.cy).abs() < rows * (a.height > b.height ? a.height : b.height);

/// Kana fragments on [f]'s row to its right that are not a bracketed
/// reading.
Iterable<Fragment> _kanaRightOf(Fragment f, List<Fragment> fragments) =>
    fragments.where(
      (k) =>
          k.kind == FragmentKind.kana &&
          k.inlineReadingOf == null &&
          k.id != f.id &&
          k.x >= f.right - 0.5 * f.height &&
          _sameRow(f, k, 1.0),
    );

/// Pairs of kanji words on one row, touching (a space apart), whose joined
/// text [isWord] may be a dictionary word: the forms to look up first.
Iterable<String> splitHeadwordForms(List<Fragment> fragments) => [
  for (final (a, b) in _splitPairs(fragments)) a.text + b.text,
];

Iterable<(Fragment, Fragment)> _splitPairs(List<Fragment> fragments) sync* {
  final heads = [
    for (final f in fragments)
      if (f.kind == FragmentKind.kanjiWord &&
          f.pass == OcrPass.japanese &&
          f.inlineReadingOf == null)
        f,
  ];
  for (final a in heads) {
    for (final b in heads) {
      if (identical(a, b) || !_sameRow(a, b, 0.5)) continue;
      final gap = b.x - a.right;
      if (gap >= -0.2 * a.height && gap <= 1.0 * a.height) yield (a, b);
    }
  }
}

/// Two kanji words a space split (`交通` `事故`) become one (`交通事故`) when
/// the joined text is a dictionary word a kana on the row reads. The second
/// fragment becomes noise (ids stay as they are).
List<Fragment> joinSplitHeadwords(
  List<Fragment> fragments, {
  required ReadsAs reads,
}) {
  final out = [...fragments];
  final done = <int>{};
  for (final (a, b) in _splitPairs(fragments)) {
    if (done.contains(a.id) || done.contains(b.id)) continue;
    final joined = a.text + b.text;
    final readings = _kanaRightOf(b, fragments);
    if (!readings.any((k) => reads(joined, k.text))) continue;
    out[a.id] = a.copyWith(
      text: joined,
      width: b.right - a.x,
      confidence: a.confidence < b.confidence ? a.confidence : b.confidence,
      corrected: true,
    );
    out[b.id] = b.copyWith(kind: FragmentKind.noise, corrected: true);
    done.addAll([a.id, b.id]);
  }
  return out;
}

/// A kana-only headword the dictionary does not know, with a look-alike
/// glyph (`ニつ`): the kanji spelling the dictionary has and a kana on the
/// same row reads (`二つ` read `ふたつ`). [known] tells whether the
/// dictionary has a form.
Map<int, Mend> mendKanaLookalikes(
  List<Fragment> fragments, {
  required bool Function(String text) known,
  required ReadsAs reads,
}) {
  final out = <int, Mend>{};
  for (final f in fragments) {
    if (f.kind != FragmentKind.kana || f.inlineReadingOf != null) continue;
    if (known(f.text)) continue;
    final readings = _kanaRightOf(f, fragments).toList();
    for (final v in kanaLookalikeVariants(f.text)) {
      if (!readings.any((k) => reads(v, k.text))) continue;
      out[f.id] = (
        fragment: f.copyWith(
          text: v,
          kind: FragmentKind.kanjiWord,
          corrected: true,
        ),
        note: '${f.text} → $v (글자 보정+사전)',
      );
      break;
    }
  }
  return out;
}

/// How far right of a headword, in its line heights, its reading may be for
/// [mendByReading].
const double readingReach = 15;

/// A kanji headword the kana on its row does not read (`体む` beside
/// `やすむ`), mended to the one dictionary spelling of that kana that differs
/// from it in a single kanji, kana and length the same (`休む`). With two
/// such spellings (`方` beside `まん`: 万, 満) nothing changes. The kana is the
/// nearest on the row to the right with no kanji word between, and no other
/// headword on the row reads it. A headword read at the engine's lowest
/// confidence is a trace of a failed read instead: it is read back from the
/// kana and the meaning (`read_back.dart`). [spellingsOf] gives the
/// dictionary's kanji spellings of a kana reading.
Map<int, Mend> mendByReading(
  List<Fragment> fragments, {
  required Iterable<String> Function(String kana) spellingsOf,
  required ReadsAs reads,
}) {
  final bracketed = {for (final f in fragments) ?f.inlineReadingOf};
  final heads = [
    for (final f in fragments)
      if (f.kind == FragmentKind.kanjiWord &&
          f.pass == OcrPass.japanese &&
          !bracketed.contains(f.id))
        f,
  ];
  final out = <int, Mend>{};
  bool mendable(Fragment f) => !atLowestConfidence(f.confidence);
  for (final f in heads.where(mendable)) {
    final kana = _nearestKanaRightOf(f, fragments);
    if (kana == null || reads(f.text, kana.text)) continue;
    if (heads.any(
      (g) => g.id != f.id && _sameRow(f, g, 1.0) && reads(g.text, kana.text),
    )) {
      continue;
    }
    final fits = {
      for (final s in spellingsOf(kana.text))
        if (_oneKanjiApart(f.text, s)) s,
    };
    if (fits.length != 1) continue;
    out[f.id] = (
      fragment: f.copyWith(text: fits.single, corrected: true),
      note: '${f.text} → ${fits.single} (글자 보정+사전 읽기)',
    );
  }
  return out;
}

Fragment? _nearestKanaRightOf(Fragment f, List<Fragment> fragments) {
  Fragment? best;
  for (final k in _kanaRightOf(f, fragments)) {
    if (k.x - f.right > readingReach * f.height) continue;
    if (best == null || k.x < best.x) best = k;
  }
  if (best == null) return null;
  final between = fragments.any(
    (g) =>
        g.kind == FragmentKind.kanjiWord &&
        g.id != f.id &&
        g.x >= f.right - 0.5 * f.height &&
        g.right <= best!.x + 0.5 * best.height &&
        _sameRow(f, g, 1.0),
  );
  return between ? null : best;
}

/// [a] and [b] have the same length and kana, and differ in exactly one
/// place where both have a kanji.
bool _oneKanjiApart(String a, String b) {
  final x = a.runes.toList(), y = b.runes.toList();
  if (x.length != y.length) return false;
  var kanjiDiffs = 0;
  for (var i = 0; i < x.length; i++) {
    if (x[i] == y[i]) continue;
    if (!isKanji(x[i]) || !isKanji(y[i])) return false;
    kanjiDiffs++;
  }
  return kanjiDiffs == 1;
}
