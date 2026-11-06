/// Splitting a Japanese sentence into dictionary words (lowest-cost path).
///
/// Every substring (up to [maxWordLength] characters) that the lexicon has,
/// as printed or after deconjugation, is an edge of the lattice with the cost
/// of [wordCost]; a character no word covers costs [LatticeCosts.unknownChar].
/// The cheapest path from start to end is the split.
library;

import 'package:shiori_core/src/extract/deconjugator.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// Longest word the lattice tries, in characters.
const int maxWordLength = 12;

/// POS codes of words that are not study items on their own.
const Set<String> functionWordCodes = {'prt', 'aux-v', 'aux-adj', 'cop', 'aux'};

/// What a kana-only expression or conjunction carries in a sentence.
const Set<String> _grammarCodes = {
  'exp',
  'conj',
  'int',
  'prt',
  'aux-v',
  'aux-adj',
  'aux',
  'cop',
  'pref',
  'suf',
};

/// Prefixes, suffixes and counters: parts of words, not words.
const Set<String> affixCodes = {'pref', 'suf', 'n-suf', 'n-pref', 'ctr'};

/// POS codes that make a word a content word even when it also has an
/// auxiliary use (行く is `v5k-s vi aux-v`).
bool _isContentCode(String c) =>
    c == 'n' ||
    c == 'n-adv' ||
    c == 'n-t' ||
    c == 'pn' ||
    c == 'num' ||
    c == 'adv' ||
    c == 'adv-to' ||
    c == 'adj-i' ||
    c == 'adj-ix' ||
    c == 'adj-na' ||
    c == 'adj-no' ||
    c == 'adj-pn' ||
    c == 'adj-t' ||
    (c.startsWith('v') && c != 'vs' && c != 'vt' && c != 'vi');

/// Whether a word with these POS codes is a particle, auxiliary, copula or
/// affix rather than a word to study.
bool isFunctionWordPos(List<String> pos) {
  if (pos.any(_isContentCode)) return false;
  return pos.any(functionWordCodes.contains) || pos.any(affixCodes.contains);
}

/// One word on the best path through a sentence.
final class LatticeToken {
  const LatticeToken({
    required this.surface,
    required this.base,
    required this.start,
    required this.end,
    this.readings = const [],
    this.partsOfSpeech = const [],
    this.steps = const [],
    this.known = true,
    this.cost = 0,
    this.entry,
  });

  /// Text as printed (`食べます`).
  final String surface;

  /// Dictionary form (`食べる`); the surface when [known] is false.
  final String base;

  /// Character offsets in the sentence (runes).
  final int start;
  final int end;
  final List<String> readings;
  final List<String> partsOfSpeech;

  /// Deconjugation steps, empty when the surface is already the base.
  final List<String> steps;

  /// The lexicon has the word; false for characters no entry covers.
  final bool known;
  final double cost;

  /// The dictionary entry the token was read as.
  final LexiconEntry? entry;

  /// Particles, auxiliaries, the copula: words that are not study items.
  bool get isFunctionWord => known && isFunctionWordPos(partsOfSpeech);

  @override
  String toString() => known ? '$surface→$base' : '?$surface';
}

/// Costs of the path (lower is better).
final class LatticeCosts {
  const LatticeCosts({
    this.words = const LatticeWordCosts(),
    this.unknownChar = 20.0,
  });

  /// Weights of a dictionary word ([wordCost]).
  final LatticeWordCosts words;

  /// Per character no dictionary word covers.
  final double unknownChar;
}

/// Characters that split a sentence before the lattice runs.
const String _breakChars =
    ' \t\n、。，．,.!?！？「」『』（）()［］[]【】〈〉《》〜～・…:：;；"“”\'‘’*＊/／|｜　';

final Set<int> _breaks = _breakChars.runes.toSet();

bool _isJapaneseLetter(int c) =>
    (c >= 0x3041 && c <= 0x309F) ||
    (c >= 0x30A0 && c <= 0x30FF) ||
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    c == 0x3005;

bool _isKana(int c) =>
    (c >= 0x3041 && c <= 0x309F) || (c >= 0x30A1 && c <= 0x30FF);

final class SentenceSegmenter {
  SentenceSegmenter(
    this.lexicon, {
    this.costs = const LatticeCosts(),
    Deconjugator? deconjugator,
  }) : deconjugator = deconjugator ?? Deconjugator.standard;

  final Lexicon lexicon;
  final LatticeCosts costs;
  final Deconjugator deconjugator;

  final Map<String, List<Deinflection>> _deconjugated = {};

  /// [_candidates] by piece: [formsFor] and the split ask for the same.
  final Map<String, Map<(int, int), List<Deinflection>>> _candidatesOf = {};

  /// Every form [segment] of [sentence] would look up, for one batched
  /// lexicon call per page.
  Set<String> formsFor(String sentence) => {
    for (final piece in _pieces(sentence))
      for (final c in _candidates(piece.text).values)
        for (final d in c) d.base,
  };

  /// The lowest-cost split of [sentence]; punctuation splits it first and is
  /// left out of the result.
  Future<List<LatticeToken>> segment(String sentence) async {
    final found = await lexicon.lookup(formsFor(sentence));
    return segmentFound(sentence, (form) => found[form] ?? const []);
  }

  /// [segment] over lookups already made: [found] answers every form of
  /// [formsFor].
  List<LatticeToken> segmentFound(
    String sentence,
    List<LexiconEntry> Function(String form) found,
  ) => [
    for (final p in _pieces(sentence))
      ..._best(p.text, p.offset, _candidates(p.text), found),
  ];

  /// [segment] without function words, unknown characters, numbers and
  /// symbols: the words a learner could study.
  Future<List<LatticeToken>> contentWords(String sentence) async =>
      onlyContent(await segment(sentence));

  /// The study words among [tokens]: known, not function words, and not a
  /// kana-only expression or conjunction (`ないといけない`, `けれども`).
  static List<LatticeToken> onlyContent(List<LatticeToken> tokens) => [
    for (final t in tokens)
      if (t.known && !t.isFunctionWord && !_kanaGrammar(t)) t,
  ];

  static bool _kanaGrammar(LatticeToken t) =>
      t.surface.runes.every((c) => c >= 0x3041 && c <= 0x309F) &&
      t.partsOfSpeech.isNotEmpty &&
      t.partsOfSpeech.every(_grammarCodes.contains);

  /// Runs of Japanese letters with their offset in the sentence.
  List<({String text, int offset})> _pieces(String sentence) {
    final out = <({String text, int offset})>[];
    final runes = sentence.runes.toList();
    var start = -1;
    for (var i = 0; i <= runes.length; i++) {
      final letter =
          i < runes.length &&
          !_breaks.contains(runes[i]) &&
          (_isJapaneseLetter(runes[i]) ||
              runes[i] == 0x30FC ||
              !_isAscii(runes[i]));
      if (letter && start < 0) start = i;
      if (!letter && start >= 0) {
        out.add((
          text: String.fromCharCodes(runes.sublist(start, i)),
          offset: start,
        ));
        start = -1;
      }
    }
    return out;
  }

  static bool _isAscii(int c) => c < 0x80;

  /// Deinflection candidates of every substring, keyed by `start:end`.
  Map<(int, int), List<Deinflection>> _candidates(String piece) =>
      _candidatesOf.putIfAbsent(piece, () => _candidatesOfPiece(piece));

  Map<(int, int), List<Deinflection>> _candidatesOfPiece(String piece) {
    final runes = piece.runes.toList();
    final out = <(int, int), List<Deinflection>>{};
    for (var i = 0; i < runes.length; i++) {
      if (!_isJapaneseLetter(runes[i])) continue;
      for (var j = i + 1; j <= runes.length && j - i <= maxWordLength; j++) {
        final s = String.fromCharCodes(runes.sublist(i, j));
        out[(i, j)] = _isKana(runes[j - 1])
            ? _deconjugated.putIfAbsent(s, () => deconjugator.deconjugate(s))
            : [Deinflection(base: s, tag: null)];
      }
    }
    return out;
  }

  List<LatticeToken> _best(
    String piece,
    int offset,
    Map<(int, int), List<Deinflection>> candidates,
    List<LexiconEntry> Function(String form) found,
  ) {
    final runes = piece.runes.toList();
    final n = runes.length;
    final best = List<double>.filled(n + 1, double.infinity)..[0] = 0;
    final back = List<LatticeToken?>.filled(n + 1, null);
    for (var i = 0; i < n; i++) {
      if (best[i] == double.infinity) continue;
      // A character no word covers.
      final unknownCost = best[i] + costs.unknownChar;
      if (unknownCost < best[i + 1]) {
        best[i + 1] = unknownCost;
        back[i + 1] = LatticeToken(
          surface: String.fromCharCode(runes[i]),
          base: String.fromCharCode(runes[i]),
          start: offset + i,
          end: offset + i + 1,
          known: false,
          cost: costs.unknownChar,
        );
      }
      for (var j = i + 1; j <= n && j - i <= maxWordLength; j++) {
        final ds = candidates[(i, j)];
        if (ds == null) continue;
        final lemmas = rankLemmas(ds, {
          for (final d in ds) d.base: found(d.base),
        }, costs: costs.words);
        if (lemmas.isEmpty) continue;
        final lemma = _usable(lemmas, j - i, atEnd: j == n);
        if (lemma == null) continue;
        final total = best[i] + lemma.cost;
        if (total < best[j]) {
          best[j] = total;
          back[j] = LatticeToken(
            surface: String.fromCharCodes(runes.sublist(i, j)),
            base: lemma.base,
            start: offset + i,
            end: offset + j,
            readings: lemma.entry.readings,
            partsOfSpeech: lemma.entry.partsOfSpeech,
            steps: lemma.steps,
            cost: lemma.cost,
            entry: lemma.entry,
          );
        }
      }
    }
    final path = <LatticeToken>[];
    for (var j = n; j > 0;) {
      final t = back[j]!;
      path.add(t);
      j = t.start - offset;
    }
    return _mergeUnknown(
      _stemsRead(path.reversed.toList(), offset, candidates, found),
    );
  }

  /// The cheapest lemma, unless a one-character kana surface would be read
  /// as a word usually written in kanji (に as 二), or the form ends in an
  /// imperative な before more of the piece (休みなので is 休み + なので,
  /// not 休みな + ので).
  static Lemma? _usable(List<Lemma> lemmas, int length, {required bool atEnd}) {
    for (final l in lemmas) {
      if (length == 1 && l.entry.isKanaForm && !l.entry.writtenInKana) continue;
      if (!atEnd && _imperativeNa.contains(l.steps.firstOrNull)) continue;
      return l;
    }
    return null;
  }

  /// [path] with every stem read as a noun before a conjugation's ending
  /// read as the verb or adjective it conjugates ([readStem]), and every
  /// expression entry that is a verb's form read as the verb
  /// ([readExpression]).
  static List<LatticeToken> _stemsRead(
    List<LatticeToken> path,
    int offset,
    Map<(int, int), List<Deinflection>> candidates,
    List<LexiconEntry> Function(String form) found,
  ) => [
    for (final (i, t) in path.indexed)
      (i + 1 < path.length
              ? readStem(t, path[i + 1], offset, candidates, found)
              : null) ??
          readExpression(t, offset, candidates, found) ??
          t,
  ];

  /// Neighbouring unknown characters as one token.
  static List<LatticeToken> _mergeUnknown(List<LatticeToken> tokens) {
    final out = <LatticeToken>[];
    for (final t in tokens) {
      final last = out.isEmpty ? null : out.last;
      if (!t.known && last != null && !last.known && last.end == t.start) {
        out[out.length - 1] = LatticeToken(
          surface: last.surface + t.surface,
          base: last.base + t.base,
          start: last.start,
          end: t.end,
          known: false,
          cost: last.cost + t.cost,
        );
      } else {
        out.add(t);
      }
    }
    return out;
  }
}

/// Rules whose ending is an imperative な (休みな, 行くな): read only at the
/// end of a piece.
const Set<String> _imperativeNa = {
  'casual polite imperative',
  'imperative negative',
};

/// Shortest start of the next token taken as a conjugation's ending: one
/// character endings (た, て) are already cheaper as the conjugated form.
const int minStemEnding = 2;

/// [t] as the verb or adjective it is the stem of, when the lattice read it
/// as a word of its own (a noun 決め) before a grammar expression that
/// swallowed the conjugation's ending (なければならない): [t] and the
/// start of [next] (longest first, at least [minStemEnding] characters) are
/// a conjugated form of that word, and [t] alone is its stem. Null when not.
/// [candidates] and [found] are the piece's (offsets from [offset]).
LatticeToken? readStem(
  LatticeToken t,
  LatticeToken next,
  int offset,
  Map<(int, int), List<Deinflection>> candidates,
  List<LexiconEntry> Function(String form) found,
) {
  if (!t.known || t.steps.isNotEmpty || t.isFunctionWord) return null;
  if (next.start != t.end || !_isKana(next.surface.runes.first)) return null;
  final a = t.start - offset, b = t.end - offset;
  List<Lemma> conjugated(int end) {
    final ds = candidates[(a, end)] ?? const <Deinflection>[];
    return [
      for (final l in rankLemmas(ds, {
        for (final d in ds) d.base: found(d.base),
      }))
        if (l.conjugated &&
            _conjugates(l.deinflection.tag) &&
            l.entry.id != t.entry?.id &&
            !_imperativeNa.contains(l.steps.firstOrNull))
          l,
    ];
  }

  final stemOf = {for (final l in conjugated(b)) l.entry.id};
  if (stemOf.isEmpty) return null;
  final ending = next.surface.runes.length;
  for (var k = ending; k >= minStemEnding; k--) {
    if (b + k - a > maxWordLength) continue;
    for (final l in conjugated(b + k)) {
      if (!stemOf.contains(l.entry.id)) continue;
      return LatticeToken(
        surface: t.surface,
        base: l.base,
        start: t.start,
        end: t.end,
        readings: l.entry.readings,
        partsOfSpeech: l.entry.partsOfSpeech,
        steps: l.steps,
        cost: t.cost,
        entry: l.entry,
      );
    }
  }
  return null;
}

/// Verb and い-adjective tags: the words a stem belongs to.
bool _conjugates(String? tag) =>
    tag != null && (tag.startsWith('v') || tag == 'adj-i');

/// Polite endings of set phrases (頂きます, 構いません, 下さい): left as
/// the expression they are registered as.
final RegExp _politeEnding = RegExp(
  r'(ます|ません|ました|まして|ましょう|です|でした|ください|下さい|なさい)$',
);

/// [t] as the verb it is a form of, when the dictionary has [t] as an
/// expression (困った, exp・adj-f) rather than the verb's form: the verb's
/// reading and classes, [t]'s surface and place. Null for a polite set
/// phrase ([_politeEnding]), a negative one (構わない), a prenominal
/// registered only as adj-f (変わった), and a form whose kanji the verb does
/// not keep (出来れば → する). [candidates] and [found] are the piece's
/// (offsets from [offset]).
LatticeToken? readExpression(
  LatticeToken t,
  int offset,
  Map<(int, int), List<Deinflection>> candidates,
  List<LexiconEntry> Function(String form) found,
) {
  final codes = t.partsOfSpeech;
  if (!t.known || t.steps.isNotEmpty || !codes.contains('exp')) return null;
  if (!codes.every((c) => c == 'exp' || c == 'adj-f')) return null;
  final runes = t.surface.runes.toList();
  final kanji = [
    for (final c in runes)
      if (!_isKana(c)) c,
  ];
  if (kanji.isEmpty || !_isKana(runes.last)) return null;
  if (_politeEnding.hasMatch(t.surface)) return null;
  final ds =
      candidates[(t.start - offset, t.end - offset)] ?? const <Deinflection>[];
  for (final l in rankLemmas(ds, {for (final d in ds) d.base: found(d.base)})) {
    if (!l.conjugated || !(l.deinflection.tag?.startsWith('v') ?? false)) {
      continue;
    }
    if (l.entry.id == t.entry?.id) continue;
    if (l.steps.any((s) => s.contains('negative'))) continue;
    final kept = l.base.runes.toSet();
    if (!kanji.every(kept.contains)) continue;
    return LatticeToken(
      surface: t.surface,
      base: l.base,
      start: t.start,
      end: t.end,
      readings: l.entry.readings,
      partsOfSpeech: l.entry.partsOfSpeech,
      steps: l.steps,
      cost: t.cost,
      entry: l.entry,
    );
  }
  return null;
}
