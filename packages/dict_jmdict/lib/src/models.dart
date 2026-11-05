import 'package:dict_jmdict/src/kana.dart' as kana;
import 'package:dict_jmdict/src/priority.dart';

/// ke_inf / re_inf codes for forms that are rare, irregular or outdated.
/// Candidates with these rank after every normal form.
const Set<String> irregularFormCodes = {
  'rK',
  'iK',
  'oK',
  'io',
  'rk',
  'ik',
  'ok',
};

/// Search-only forms (common misspellings). Accepted by pair checks, never
/// offered as a candidate.
const Set<String> searchOnlyFormCodes = {'sK', 'sk'};

/// Coarse word classes, matching the POS badges a textbook prints
/// (명 동 형 부 접 감 연 조). Used to rank candidates, never to filter them.
enum WordClass {
  noun,
  verb,
  iAdjective,
  naAdjective,
  adverb,
  conjunction,
  interjection,
  adnominal,
  particle,
}

/// Classes of a word from its JMdict POS codes. `vs` (suru noun), `vt` and
/// `vi` are not verbs on their own; `num`, `pn` and `ctr` count as nouns.
Set<WordClass> wordClassesOf(Iterable<String> posCodes) => {
  for (final code in posCodes) ?_wordClassOf(code),
};

WordClass? _wordClassOf(String code) => switch (code) {
  'n' || 'n-suf' || 'n-pref' || 'n-pr' || 'num' || 'pn' || 'ctr' => .noun,
  'vs' || 'vt' || 'vi' => null,
  'adj-i' || 'adj-ix' => .iAdjective,
  'adj-na' => .naAdjective,
  'adv' || 'adv-to' => .adverb,
  'conj' => .conjunction,
  'int' => .interjection,
  'adj-pn' => .adnominal,
  'prt' => .particle,
  _ when code.startsWith('v') && !code.startsWith('vs') => .verb,
  'vs-i' || 'vs-s' || 'vs-c' => .verb,
  _ => null,
};

/// Where the data came from; read from the database's `meta` table.
final class DictionaryInfo {
  const DictionaryInfo(this.values);

  final Map<String, String> values;

  int get schemaVersion => int.tryParse(values['schema_version'] ?? '') ?? 0;

  /// Date in the JMdict file header, for example `2026-11-04`.
  String get jmdictCreated => values['jmdict_created'] ?? '';
  String get sourceSha256 => values['source_sha256'] ?? '';
  int get entryCount => int.tryParse(values['entry_count'] ?? '') ?? 0;

  /// `all` or `common` entries.
  String get entries => values['entries'] ?? '';

  /// `all`, `first` or `none` English glosses.
  String get glosses => values['glosses'] ?? '';
  String get license => values['license'] ?? '';
  String get licenseUrl => values['license_url'] ?? '';
  String get projectUrl => values['project_url'] ?? '';

  /// The notice the EDRDG licence requires the app to show.
  String get attribution => values['attribution'] ?? '';
}

/// A headword that the dictionary prints with a given reading.
final class HeadwordCandidate {
  const HeadwordCandidate({
    required this.headword,
    required this.reading,
    required this.entryId,
    required this.priority,
    this.formInfo = const [],
    this.partsOfSpeech = const [],
    this.glosses = const [],
  });

  /// Kanji form, or the kana itself for words written in kana.
  final String headword;
  final String reading;

  /// JMdict `ent_seq`.
  final int entryId;

  /// Priority of this headword/reading pair ([Priority.pair]).
  final Priority priority;

  /// ke_inf / re_inf codes of the form, for example `rK` or `ateji`.
  final List<String> formInfo;

  /// JMdict POS codes of the entry, for example `n`, `v5r`, `num`.
  final List<String> partsOfSpeech;

  /// English glosses of the first sense; empty when the database has none.
  final List<String> glosses;

  bool get isKanaOnly => kana.isKanaOnly(headword);
  bool get isIrregular => formInfo.any(irregularFormCodes.contains);
  bool get isSearchOnly => formInfo.any(searchOnlyFormCodes.contains);

  /// Why the candidate ranks where it does, for example `common news1 ichi1 nf01`.
  String get rankReason => [
    if (priority.isCommon) 'common',
    ...priority.codes,
    if (priority.codes.isEmpty) 'no-priority',
    ...formInfo,
  ].join(' ');

  @override
  String toString() => '$headword【$reading】#$entryId $rankReason';
}

enum GlyphEditKind {
  /// A look-alike glyph from the confusable table (タ → 夕).
  lookAlike,

  /// The same kana in the other script (ベ → べ).
  kanaScript,
}

/// One glyph change from the OCR text to a dictionary form.
final class GlyphEdit {
  const GlyphEdit(this.index, this.from, this.to, this.kind);

  /// Position in the OCR text, counted in characters (runes).
  final int index;
  final String from;
  final String to;
  final GlyphEditKind kind;

  @override
  bool operator ==(Object other) =>
      other is GlyphEdit &&
      other.index == index &&
      other.from == from &&
      other.to == to &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(index, from, to, kind);

  @override
  String toString() => '$from→$to@$index';
}

/// How a suggestion was found.
enum SuggestionBasis {
  /// The OCR text matched a dictionary form, maybe after [GlyphEdit]s.
  glyphs,

  /// Nothing was read as the headword; candidates come from the reading only.
  readingOnly,
}

final class HeadwordSuggestion {
  const HeadwordSuggestion(this.candidate, this.basis, [this.edits = const []]);

  final HeadwordCandidate candidate;
  final SuggestionBasis basis;

  /// Changes from the OCR text; empty when the OCR text is already this form.
  final List<GlyphEdit> edits;

  String get headword => candidate.headword;

  /// The OCR text is already a dictionary form.
  bool get confirmsOcr => basis == SuggestionBasis.glyphs && edits.isEmpty;

  @override
  String toString() =>
      '$headword ${edits.isEmpty ? '' : edits} (${candidate.rankReason})';
}

/// How a textbook headword/reading pair was found in the dictionary.
enum PairMatch {
  /// The dictionary has this headword with this reading (or this kana word).
  exact,

  /// Found after folding hiragana and katakana (ゴミ ~ ごみ).
  kanaScript,

  /// Okurigana differ (締切 ~ 締め切り).
  spellingVariant,

  /// Found after removing 〜, parentheses, or a する / な ending.
  affixStripped,

  /// Two dictionary words in a row (材料 + 費), rendaku allowed.
  compound,

  /// Not found. The review screen should ask the learner to check.
  none,
}

final class PairCheck {
  const PairCheck(
    this.match, {
    this.dictionaryForm,
    this.entryId,
    this.parts = const [],
  });

  static const notFound = PairCheck(PairMatch.none);

  final PairMatch match;

  /// The dictionary's spelling that matched, when it differs from the input.
  final String? dictionaryForm;

  /// JMdict `ent_seq` of the match (the first part for a compound).
  final int? entryId;

  /// The two words of a [PairMatch.compound].
  final List<String> parts;

  bool get isKnown => match != PairMatch.none;

  @override
  String toString() => [
    match.name,
    ?dictionaryForm,
    if (parts.isNotEmpty) parts.join('+'),
  ].join(' ');
}
