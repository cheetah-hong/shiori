/// Dictionary forms of conjugated words (`食べました` → `食べる`).
///
/// The rules are JL's `deconjugation_rules.json` (Apache-2.0,
/// packages/core/third_party/jl). Each rule turns an ending back into an
/// earlier one (`ました` → `ます`, `ます` → `る` on a ren'youkei stem) and
/// moves a form from one tag to another; a chain of rules that ends on a
/// part-of-speech tag (`v1`, `v5k`, `adj-i`, ...) proposes a dictionary form,
/// which [Lemmatizer] keeps only when the lexicon has it with that POS.
///
/// Rule types, as the file defines them:
/// - `stdrule`: applies anywhere in the chain;
/// - `onlyfinalrule`: only to the text as printed (the last conjugation);
/// - `neverfinalrule`: never to the text as printed;
/// - `rewriterule`: only when the whole text is the ending (`でした`).
/// A rule with an empty detail may not be the first one applied.
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shiori_core/src/extract/data/deconjugation_rules.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// One way back from a surface form to a dictionary form.
final class Deinflection {
  const Deinflection({
    required this.base,
    required this.tag,
    this.steps = const [],
  });

  /// Candidate dictionary form.
  final String base;

  /// JMdict POS code the base must have (`v1`, `v5k`, `adj-i`, ...), or
  /// null for the surface itself (no rule applied).
  final String? tag;

  /// Rule details, outermost first (`polite past` …).
  final List<String> steps;

  @override
  String toString() => '$base[$tag] ${steps.join(' < ')}';
}

enum _RuleType { std, onlyFinal, neverFinal, rewrite }

final class _Rule {
  const _Rule(
    this.type,
    this.decEnd,
    this.conEnd,
    this.decTag,
    this.conTag,
    this.detail,
  );

  final _RuleType type;
  final String decEnd;
  final String conEnd;
  final String decTag;
  final String conTag;
  final String detail;
}

/// Rules this project adds to the file: な-adjectives before a noun, as an
/// adverb, before the copula (`静かな`, `静かに`, `静かだ`, `静かで`). The
/// file treats な and に as separate particles; a word list prints the
/// attributive form as one word.
const List<(String, String)> _naAdjectiveEndings = [
  ('な', 'attributive な'),
  ('に', 'adverbial に'),
  ('だ', 'predicative だ'),
  ('で', 'conjunctive で'),
];

/// POS tags a dictionary form can carry (the rest are stems and forms
/// inside a chain).
bool _isWordTag(String tag) =>
    tag.startsWith('v') || tag.startsWith('adj-') || tag == 'cop';

/// The rule engine over the bundled JL rule file.
final class Deconjugator {
  /// [indexed]: try on a form only the rules whose ending it ends in (the
  /// same candidates in the same order as trying every rule, much faster on
  /// a sentence page's thousand substrings); false tries every rule.
  Deconjugator(String rulesJson, {this.indexed = true})
    : _rules = _parseRules(rulesJson) {
    if (!indexed) return;
    for (final (i, r) in _rules.indexed) {
      if (r.conEnd.isEmpty) {
        _anyEnding.add(i);
      } else {
        (_byLastChar[r.conEnd.runes.last] ??= []).add(i);
      }
    }
  }

  /// The bundled rules (packages/core/third_party/jl).
  static final Deconjugator standard = Deconjugator(deconjugationRulesJson);

  final List<_Rule> _rules;

  /// Rules are looked up by the last character of their ending.
  final bool indexed;

  /// Rule positions by the last character of the ending they take off.
  final Map<int, List<int>> _byLastChar = {};

  /// Rule positions whose ending is empty (they fit any form).
  final List<int> _anyEnding = [];

  /// The rules that may apply to [text], in file order.
  Iterable<_Rule> _rulesFor(String text) {
    if (!indexed) return _rules;
    if (text.isEmpty) return const [];
    final byEnd = _byLastChar[text.runes.last] ?? const <int>[];
    if (_anyEnding.isEmpty) return [for (final i in byEnd) _rules[i]];
    return [for (final i in _merged(byEnd, _anyEnding)) _rules[i]];
  }

  /// Two ascending lists of positions as one.
  static List<int> _merged(List<int> a, List<int> b) {
    final out = <int>[];
    var i = 0, j = 0;
    while (i < a.length || j < b.length) {
      if (j >= b.length || (i < a.length && a[i] < b[j])) {
        out.add(a[i++]);
      } else {
        out.add(b[j++]);
      }
    }
    return out;
  }

  /// How far a chain may grow past the printed text, as in the reference
  /// engine: bases at most 10 characters longer, at most 6 tags more.
  static const int _maxGrowth = 10;
  static const int _maxExtraTags = 6;

  /// Every candidate dictionary form of [surface], including [surface] itself
  /// (tag null). Only chains that end on a word tag are returned. Not checked
  /// against a dictionary.
  List<Deinflection> deconjugate(String surface) {
    if (surface.isEmpty) return const [];
    final start = _Form(surface, const [], const []);
    final seen = <String>{start.key};
    final queue = Queue<_Form>.of([start]);
    final out = <Deinflection>[Deinflection(base: surface, tag: null)];
    final maxLength = surface.length + _maxGrowth;
    final maxTags = surface.length + _maxExtraTags;
    while (queue.isNotEmpty) {
      final form = queue.removeFirst();
      for (final rule in _rulesFor(form.text)) {
        final next = _apply(form, rule);
        if (next == null ||
            next.text.length > maxLength ||
            next.tags.length > maxTags ||
            !seen.add(next.key)) {
          continue;
        }
        queue.add(next);
        if (_isWordTag(next.tags.last)) {
          out.add(
            Deinflection(
              base: next.text,
              tag: next.tags.last,
              steps: next.steps,
            ),
          );
        }
      }
    }
    return List.unmodifiable(out);
  }

  static _Form? _apply(_Form form, _Rule rule) {
    if (form.text.isEmpty) return null;
    final first = form.tags.isEmpty;
    if (rule.detail.isEmpty && first) return null;
    switch (rule.type) {
      case _RuleType.onlyFinal when !first:
      case _RuleType.neverFinal when first:
        return null;
      case _RuleType.rewrite when form.text != rule.conEnd:
        return null;
      case _:
    }
    if (!first && form.tags.last != rule.conTag) return null;
    if (!form.text.endsWith(rule.conEnd)) return null;
    final text =
        form.text.substring(0, form.text.length - rule.conEnd.length) +
        rule.decEnd;
    return _Form(
      text,
      [if (first) rule.conTag, ...form.tags, rule.decTag],
      [...form.steps, if (rule.detail.isNotEmpty) rule.detail],
    );
  }

  static List<_Rule> _parseRules(String json) {
    final raw = jsonDecode(json);
    if (raw is! List) {
      throw const FormatException('deconjugation rules must be a JSON list');
    }
    final rules = <_Rule>[];
    for (final r in raw) {
      if (r is! Map) throw FormatException('rule must be an object', r);
      final type = switch (r['type']) {
        'stdrule' => _RuleType.std,
        'onlyfinalrule' => _RuleType.onlyFinal,
        'neverfinalrule' => _RuleType.neverFinal,
        'rewriterule' => _RuleType.rewrite,
        final t => throw FormatException('unknown rule type', t),
      };
      final decEnd = _strings(r['dec_end']);
      final conEnd = _strings(r['con_end']);
      final decTag = _strings(r['dec_tag']);
      final conTag = _strings(r['con_tag']);
      final detail = r['detail'];
      if (detail is! String) throw FormatException('rule detail', r);
      final n = [
        decEnd,
        conEnd,
        decTag,
        conTag,
      ].map((l) => l.length).reduce(math.max);
      String at(List<String> l, int i) => l.length == 1 ? l.single : l[i];
      for (final l in [decEnd, conEnd, decTag, conTag]) {
        if (l.length != 1 && l.length != n) {
          throw FormatException('rule arrays differ in length', r);
        }
      }
      for (var i = 0; i < n; i++) {
        rules.add(
          _Rule(
            type,
            at(decEnd, i),
            at(conEnd, i),
            at(decTag, i),
            at(conTag, i),
            detail,
          ),
        );
      }
    }
    for (final (ending, detail) in _naAdjectiveEndings) {
      rules.add(
        _Rule(_RuleType.onlyFinal, '', ending, 'adj-na', 'na-$ending', detail),
      );
    }
    return List.unmodifiable(rules);
  }

  static List<String> _strings(Object? v) => switch (v) {
    final String s => [s],
    final List<Object?> l when l.isNotEmpty && l.every((s) => s is String) =>
      l.cast<String>(),
    _ => throw FormatException('rule field must be a string list', v),
  };
}

final class _Form {
  const _Form(this.text, this.tags, this.steps);

  final String text;
  final List<String> tags;
  final List<String> steps;

  String get key => '$text\u0000${tags.join(' ')}';
}

/// A dictionary form confirmed by the lexicon.
final class Lemma {
  const Lemma({
    required this.deinflection,
    required this.entry,
    required this.cost,
  });

  final Deinflection deinflection;
  final LexiconEntry entry;

  /// Lower is more likely ([wordCost]).
  final double cost;

  String get base => deinflection.base;
  List<String> get steps => deinflection.steps;
  bool get conjugated => deinflection.tag != null;
}

/// Verb classes whose conjugations are irregular: when a printed form fits
/// one of them, that verb is what the page means (行った is 行く, not 行う).
const Set<String> irregularVerbClasses = {
  'v5k-s',
  'vk',
  'vs-i',
  'vs-s',
  'v5r-i',
  'v5aru',
  'v5u-s',
  'v1-s',
  'vz',
};

/// Frequency rank estimated from JMdict priorities: a common word's nfXX
/// band (500 words each), else a fixed rank per priority level.
double estimatedRank(LexiconEntry e) {
  if (e.isCommon) return e.nf == null ? 3000 : 500.0 * e.nf!;
  if (e.priority != 0) return 20000;
  return 60000;
}

/// Cost of reading [d] as [e]; [LatticeWordCosts] holds the weights.
double wordCost(
  LexiconEntry e,
  Deinflection d, {
  LatticeWordCosts costs = const LatticeWordCosts(),
}) {
  var cost = costs.wordBase + math.log(estimatedRank(e));
  if (d.tag != null) cost += costs.conjugated;
  if (d.tag != null && irregularVerbClasses.contains(d.tag)) {
    cost -= costs.irregularRule;
  }
  if (e.isKanaForm && !e.writtenInKana && !_isKatakana(e.form)) {
    cost += costs.kanaSpelling;
  }
  return cost;
}

bool _isKatakana(String s) =>
    s.runes.every((r) => (r >= 0x30A1 && r <= 0x30FA) || r == 0x30FC);

/// The word weights shared by [Lemmatizer] and the sentence lattice.
final class LatticeWordCosts {
  const LatticeWordCosts({
    this.wordBase = 6.0,
    this.conjugated = 1.5,
    this.kanaSpelling = 6.0,
    this.irregularRule = 3.0,
  });

  /// Added to ln(estimated frequency rank) for every word.
  final double wordBase;

  /// Extra for a deconjugated word.
  final double conjugated;

  /// Extra for a kana spelling of a word usually written in kanji.
  final double kanaSpelling;

  /// Taken off when the rule chain ends on an irregular verb class.
  final double irregularRule;
}

/// Whether [e] can be the dictionary form [d] proposes.
bool fitsRule(LexiconEntry e, Deinflection d) {
  final tag = d.tag;
  if (tag == null) return true;
  return e.partsOfSpeech.contains(tag);
}

/// Deconjugates and keeps only bases the lexicon has with the rule's POS.
final class Lemmatizer {
  Lemmatizer(
    this.lexicon, {
    Deconjugator? deconjugator,
    this.costs = const LatticeWordCosts(),
  }) : deconjugator = deconjugator ?? Deconjugator.standard;

  final Lexicon lexicon;
  final Deconjugator deconjugator;
  final LatticeWordCosts costs;

  /// Confirmed dictionary forms of [surface], most likely first.
  Future<List<Lemma>> lemmas(String surface) async {
    final candidates = deconjugator.deconjugate(surface);
    final found = await lexicon.lookup({for (final d in candidates) d.base});
    return rankLemmas(candidates, found, costs: costs);
  }
}

/// [candidates] the lexicon confirms ([found] holds its answers), cheapest
/// first; one lemma per entry and base.
List<Lemma> rankLemmas(
  List<Deinflection> candidates,
  Map<String, List<LexiconEntry>> found, {
  LatticeWordCosts costs = const LatticeWordCosts(),
}) {
  final best = <String, Lemma>{};
  for (final d in candidates) {
    for (final e in found[d.base] ?? const <LexiconEntry>[]) {
      if (!fitsRule(e, d)) continue;
      final lemma = Lemma(
        deinflection: d,
        entry: e,
        cost: wordCost(e, d, costs: costs),
      );
      final key = '${e.id}\u0000${d.base}';
      final kept = best[key];
      if (kept == null || lemma.cost < kept.cost) best[key] = lemma;
    }
  }
  final out = best.values.toList()..sort((a, b) => a.cost.compareTo(b.cost));
  return List.unmodifiable(out);
}
