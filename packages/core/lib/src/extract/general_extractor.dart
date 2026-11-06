/// The word extractor that does not depend on a page layout.
///
/// 1. Fragments from both OCR passes ([collectFragments]).
/// 2. One batched lexicon lookup for every form the page needs.
/// 3. Headword ↔ reading: inline brackets, else a Hungarian assignment on
///    dictionary agreement and placement; missing readings from the dictionary.
/// 4. Headword ↔ Korean: a Hungarian assignment on Korean readings of the
///    kanji, the Korean gloss lookup, and placement corrected for row tilt.
/// 5. Japanese sentences → dictionary-form content words, with the sentence
///    and its translation as the example.
/// 6. One word per headword; known headwords dropped; leftovers kept.
library;

import 'package:shiori_core/src/capture/correctors/confusables.dart';
import 'package:shiori_core/src/extract/confidence.dart';
import 'package:shiori_core/src/extract/deconjugator.dart';
import 'package:shiori_core/src/extract/extracted_word.dart';
import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/extract/fragment_collector.dart';
import 'package:shiori_core/src/extract/hanja.dart';
import 'package:shiori_core/src/extract/headword_repair.dart';
import 'package:shiori_core/src/extract/hungarian.dart';
import 'package:shiori_core/src/extract/lattice.dart';
import 'package:shiori_core/src/extract/meaning_marks.dart';
import 'package:shiori_core/src/extract/pairing.dart';
import 'package:shiori_core/src/extract/read_back.dart';
import 'package:shiori_core/src/extract/script_runs.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// Korean words a dictionary gives for a headword (a Korean gloss block
/// plugs in here); empty when it knows none.
typedef KoreanGlossLookup =
    Future<List<String>> Function(String headword, List<String> readings);

/// The words of every sense [glossary] gives, as a [KoreanGlossLookup]. A
/// glossary that fails (a damaged file) gives none: the page still pairs on
/// the Korean readings of the kanji and placement.
KoreanGlossLookup glossLookupOf(KoreanGlossary glossary) =>
    (headword, readings) async {
      try {
        return [
          for (final s in await glossary.lookup(
            headword,
            readings: readings,
            limit: glossarySenses,
          ))
            ...s.words,
        ];
      } on Exception {
        return const [];
      }
    };

/// Senses asked of the glossary per word: the first is the meaning, the
/// others candidates.
const int glossarySenses = 3;

/// A kanji readings match needs this many Korean syllables (one syllable
/// matches by chance too often).
const int minHanjaSyllables = 2;

/// Japanese sentences read at this OCR confidence or lower give no words
/// (Apple Vision gives 0.3 to lines it barely made out).
const double lowestSentenceConfidence = lowestOcrConfidence;

/// OCR scan → fragments → headword, reading and meaning pairing → words.
///
/// Sentences become dictionary-form words with the sentence as their example.
final class GeneralExtractor {
  GeneralExtractor({
    this.lexicon = const EmptyLexicon(),
    KoreanGlossLookup? koreanGlosses,
    this.koreanGlossary,
    this.weights = const PairWeights(),
  }) : _givenGlosses = koreanGlosses;

  final KoreanGlossLookup? _givenGlosses;

  final Lexicon lexicon;

  /// Korean words for a headword: a pairing signal. Given, or made from
  /// [koreanGlossary].
  KoreanGlossLookup? get koreanGlosses =>
      _givenGlosses ??
      (koreanGlossary == null ? null : glossLookupOf(koreanGlossary!));

  /// The Korean glossary block: its words are a pairing signal (through
  /// [koreanGlosses]) and its first sense the meaning of a dictionary word
  /// the page gives none; the other senses are offered as candidates.
  final KoreanGlossary? koreanGlossary;
  final PairWeights weights;

  /// Words on the page. Headwords in [knownHeadwords] (already in the
  /// learner's lists) are left out.
  Future<ExtractionResult> extract(
    OcrScan scan, {
    Set<String> knownHeadwords = const {},
  }) async {
    final watch = Stopwatch()..start();
    final fragments = collectFragments(scan);
    final page = _Page(
      fragments,
      _CachingLexicon(lexicon),
      hasLexicon: lexicon is! EmptyLexicon,
    );
    final senses = _SenseCache(koreanGlossary);
    final glosses =
        _givenGlosses ?? (koreanGlossary == null ? null : senses.words);
    await page.prefetch();
    page
      ..restoreBoxPrefixes()
      ..mendHeadwords();
    await page.mendFromReadings();
    final heads = page.headwords();
    final readings = page.pairReadings(heads, weights);
    final items = [...heads.values, ...page.kanaWords(readings.used)];
    final meanings = await page.pairMeanings(
      items,
      readings.slopes,
      glosses,
      weights,
      withReading: readings.links.keys.toSet(),
    );
    final sentenceWords = page.sentenceWords(meanings.used, weights);
    var found = [
      for (final item in items)
        if (item.isWord(
          page.hasLexicon,
          meanings.links[item.fragment.id],
          reading: readings.links[item.fragment.id],
          inKoreanParagraph: page.inKoreanParagraph(item.fragment),
          lineHeight: page.lineHeight,
        ))
          item.toWord(
            readings.links[item.fragment.id],
            meanings.links[item.fragment.id],
            page.fragments,
          ),
      ...sentenceWords.words,
    ];
    var traces = const <int>{};
    if (koreanGlossary case final KoreanReverseGlossary backwards) {
      (words: found, traces: traces) = await readBackHeadwords(
        found,
        fragments: page.fragments,
        used: {
          ...readings.used,
          ...meanings.used,
          ...sentenceWords.used,
          for (final w in found) ?w.headwordFragmentId,
        },
        glossary: backwards,
        lexicon: page.lexicon,
      );
    }
    found = page.withoutLonelyWords(found);
    final merged = _merge(found);
    final skipped = <String>[];
    final kept = <ExtractedWord>[];
    for (final w in merged) {
      if (!_isKnown(w.headword, knownHeadwords)) {
        kept.add(w);
      } else if (!skipped.contains(w.headword)) {
        skipped.add(w.headword);
      }
    }
    final filled = koreanGlossary == null
        ? kept
        : [for (final w in kept) await senses.fill(w)];
    // After merging: the merge picks between words by their confidence.
    final settled = await settleConfidence(
      filled,
      fragments: page.fragments,
      items: page.confidenceItems(items, readings.slopes),
      glosses: glosses,
      // Before merging and leaving known words out: their fragments are
      // taken too, not traces of a lost headword.
      taken: {
        ...readings.used,
        ...meanings.used,
        ...traces,
        for (final w in found)
          if (w.origin == WordOrigin.wordList) ?w.headwordFragmentId,
      },
    );
    final words = [for (final w in settled) _unsettledHeadword(w)];
    final all = page.fragments;
    final used = <int>{
      ...readings.used,
      ...meanings.used,
      ...sentenceWords.used,
      // Every word found, also one merged into another of the same
      // headword or left out as known: its fragment is not unpaired.
      for (final w in found) ?w.headwordFragmentId,
      for (final f in all)
        if (f.inlineReadingOf != null) f.id,
      // What OCR left of a headword that was read back.
      ...traces,
      ...page.strayOverWords({for (final w in found) ?w.headwordFragmentId}),
    };
    return ExtractionResult(
      words: List.unmodifiable(words),
      unpaired: List.unmodifiable([
        for (final f in all)
          if (f.isContent && !used.contains(f.id) && !page.isGarbage(f)) f,
      ]),
      fragments: List.unmodifiable(all),
      elapsed: watch.elapsed,
      skippedKnown: List.unmodifiable(skipped),
    );
  }
}

/// Korean senses per word, asked once; a glossary that fails gives none.
final class _SenseCache {
  _SenseCache(this.glossary);

  final KoreanGlossary? glossary;
  final Map<String, List<KoreanSense>> _found = {};

  Future<List<KoreanSense>> of(String headword, List<String> readings) async {
    final g = glossary;
    if (g == null) return const [];
    final key = '$headword|${readings.join('/')}';
    final known = _found[key];
    if (known != null) return known;
    List<KoreanSense> found;
    try {
      found = await g.lookup(
        headword,
        readings: readings,
        limit: glossarySenses,
      );
    } on Exception {
      // A damaged glossary file: the page still pairs on content and place.
      found = const [];
    }
    return _found[key] = found;
  }

  /// As a [KoreanGlossLookup]: the words of every sense.
  Future<List<String>> words(String headword, List<String> readings) async => [
    for (final s in await of(headword, readings)) ...s.words,
  ];

  /// A dictionary word with no meaning on the page takes the first sense
  /// (source: dictionary, never high); the other senses become candidates.
  Future<ExtractedWord> fill(ExtractedWord w) async {
    // Only words the lexicon knows: a meaning for a misread one would look
    // checked.
    if (w.partsOfSpeech.isEmpty) return w;
    var found = await of(w.headword, w.readings);
    // `(お)みやげ`: the word without its optional prefix's brackets.
    for (final form in optionalPrefixForms(w.headword)) {
      if (found.isNotEmpty) break;
      found = await of(form, w.readings);
    }
    if (found.isEmpty) return w;
    final meaning = w.meaning;
    if (meaning == null) {
      return w.copyWith(
        meaning: found.first.text,
        meaningSource: FieldSource.dictionary,
        meaningLink: const PairLink(
          confidence: PairConfidence.medium,
          signals: {PairSignal.koreanGloss},
          note: 'dictionary meaning',
        ),
        meaningCandidates: [for (final s in found.skip(1)) s.text],
      );
    }
    final others = [
      for (final s in found)
        if (_bare(s.text) != _bare(meaning)) s.text,
    ];
    return others.isEmpty ? w : w.copyWith(meaningCandidates: others);
  }
}

/// Memoizes lookups so the page's one batched call serves every later step.
final class _CachingLexicon implements Lexicon {
  _CachingLexicon(this.inner);

  final Lexicon inner;
  final Map<String, List<LexiconEntry>> _known = {};
  final Set<String> _missing = {};

  @override
  Future<Map<String, List<LexiconEntry>>> lookup(Iterable<String> forms) async {
    final wanted = forms.toSet();
    final ask = wanted
        .where((f) => !_known.containsKey(f) && !_missing.contains(f))
        .toList();
    if (ask.isNotEmpty) {
      final found = await inner.lookup(ask);
      for (final f in ask) {
        final e = found[f];
        if (e == null || e.isEmpty) {
          _missing.add(f);
        } else {
          _known[f] = e;
        }
      }
    }
    return {for (final f in wanted) f: ?_known[f]};
  }

  /// Synchronous view of what [lookup] fetched.
  List<LexiconEntry> cached(String form) => _known[form] ?? const [];
}

/// A word-list item: a headword or a kana word on the page.
final class _Item {
  _Item(
    this.fragment,
    this.lemmas, {
    this.inlineReading,
    this.kanjiCandidates = const [],
    this.kanjiPos = const {},
    this.headwordNote,
  });

  final Fragment fragment;

  /// Why the headword is not what OCR read (a look-alike glyph fixed).
  final String? headwordNote;

  /// Dictionary forms the lexicon confirms, best first (empty: unknown).
  final List<Lemma> lemmas;
  final Fragment? inlineReading;

  /// For kana the lexicon knows only as the reading of kanji words (a
  /// headword OCR did not read): those kanji forms, most frequent first.
  final List<String> kanjiCandidates;

  /// POS codes of each of [kanjiCandidates].
  final Map<String, List<String>> kanjiPos;

  /// The Korean text spells the headword's kanji in Korean readings (for
  /// an orphan reading, one of its kanji forms'), as the pairing counts it.
  bool namesMeaning(String korean) => kanjiCandidates.isNotEmpty
      ? kanjiNaming(korean) != null
      : !isKana && hanjaNamesMeaning(headword, korean);

  /// Readings the Korean gloss lookup is asked with, as the pairing asks.
  List<String> get glossReadings => [
    ...readingParts(inlineReading?.text ?? ''),
    ...?entry?.readings,
  ];

  /// Kana the lexicon has only as kanji words' reading, not as a word.
  bool get isOrphanReading => kanjiCandidates.isNotEmpty && lemmas.isEmpty;

  /// The kanji form whose Korean reading names [meaning] (`やま` with
  /// `산` → 山), or null.
  String? kanjiNaming(String meaning) {
    for (final k in kanjiCandidates) {
      if (hanjaNamesWord(k, meaning) ||
          hanjaMatchLength(k, meaning) >= minHanjaSyllables) {
        return k;
      }
    }
    return null;
  }

  String get headword => fragment.text;
  bool get known => lemmas.isNotEmpty;
  bool get isKana => fragment.kind == FragmentKind.kana;
  LexiconEntry? get entry => lemmas.isEmpty ? null : lemmas.first.entry;

  /// The suffix the headword prints after its dictionary form (`丈夫だ` → `だ`).
  String get printedSuffix {
    final base = lemmas.isEmpty ? headword : lemmas.first.base;
    return headword.startsWith(base) ? headword.substring(base.length) : '';
  }

  /// Hiragana readings the dictionary gives for the headword as printed.
  Set<String> get dictionaryReadings => {
    for (final l in lemmas)
      for (final r in l.entry.readings) _hiragana(r) + _hiragana(printedSuffix),
  };

  /// Every reading [text] prints is one the dictionary gives the headword.
  bool readsAs(String text) {
    final parts = readingParts(text);
    final known = dictionaryReadings;
    return parts.isNotEmpty && parts.every((r) => known.contains(_hiragana(r)));
  }

  bool isWord(
    bool hasLexicon,
    PairLink? meaning, {
    PairLink? reading,
    bool inKoreanParagraph = false,
    double? lineHeight,
  }) {
    if (isOrphanReading) return meaning != null;
    final alone = meaning == null && reading == null && inlineReading == null;
    // The Japanese pass read a line of a Korean explanation as words.
    if (inKoreanParagraph && alone) return false;
    // One kana with nothing paired, or paired by place alone, is a stray
    // glyph, not a word.
    if (isKana &&
        fragment.text.runes.length == 1 &&
        reading == null &&
        inlineReading == null &&
        (meaning == null ||
            meaning.signals.every((s) => s == PairSignal.position))) {
      return false;
    }
    // Kana in furigana size with nothing paired: a stray reading, not a
    // headword (headwords are printed in the page's type).
    if (isKana &&
        alone &&
        lineHeight != null &&
        fragment.height <= furiganaSize * lineHeight) {
      return false;
    }
    // Kana no dictionary has, read at the engine's lowest confidence and
    // paired by place only: garbage beside some Korean line.
    if (hasLexicon &&
        isKana &&
        !known &&
        atLowestConfidence(fragment.confidence) &&
        reading == null &&
        (meaning == null ||
            meaning.signals.every((s) => s == PairSignal.position))) {
      return false;
    }
    // Read at the engine's lowest confidence and paired with nothing: the
    // Japanese pass's garbage over Korean text more often than a word.
    if (hasLexicon &&
        atLowestConfidence(fragment.confidence) &&
        meaning == null &&
        reading == null &&
        inlineReading == null) {
      return false;
    }
    if (!hasLexicon || known || inlineReading != null) return true;
    return meaning != null;
  }

  ExtractedWord toWord(
    PairLink? reading,
    PairLink? meaning,
    List<Fragment> fragments,
  ) {
    final readingFragment = reading?.fragmentId == null
        ? null
        : fragments[reading!.fragmentId!];
    final meaningFragment = meaning?.fragmentId == null
        ? null
        : fragments[meaning!.fragmentId!];
    final parts = [fragment, ?readingFragment, ?meaningFragment];
    final named = kanjiCandidates.isNotEmpty && meaningFragment != null
        ? kanjiNaming(meaningFragment.text)
        : null;
    if (named != null) {
      // The headword was not read: the dictionary's kanji for this reading
      // whose Korean reading is the meaning.
      return ExtractedWord(
        headword: named,
        origin: WordOrigin.wordList,
        readings: readingParts(fragment.text),
        partsOfSpeech: kanjiPos[named] ?? const [],
        meaning: meaningFragment!.text,
        meaningNotes: meaningFragment.notes,
        headwordSource: FieldSource.dictionary,
        readingSource: FieldSource.photo,
        meaningSource: FieldSource.photo,
        readingLink: PairLink(
          confidence: PairConfidence.medium,
          signals: const {PairSignal.dictionaryPair},
          fragmentId: fragment.id,
        ),
        meaningLink: meaning,
        readQuality: ReadQuality(
          ocrConfidence: parts
              .map((f) => f.confidence)
              .reduce((a, b) => a < b ? a : b),
          corrected: parts.any((f) => f.corrected),
        ),
        headwordFragmentId: fragment.id,
      );
    }
    final dictionaryReading = isKana || reading != null || !known
        ? null
        : _dictionaryReading();
    final readingLink = reading ?? dictionaryReading?.link;
    return ExtractedWord(
      headword: headword,
      origin: WordOrigin.wordList,
      readings: [
        if (readingFragment != null)
          ...readingParts(readingFragment.text)
        else
          ?dictionaryReading?.reading,
      ],
      meaning: meaningFragment?.text,
      meaningNotes: meaningFragment?.notes ?? const [],
      // No dictionary entry: the badge before the meaning, if printed.
      partsOfSpeech:
          entry?.partsOfSpeech ?? meaningFragment?.badgeCodes ?? const [],
      readingSource: readingFragment != null
          ? FieldSource.photo
          : (dictionaryReading == null ? null : FieldSource.dictionary),
      meaningSource: meaningFragment == null ? null : FieldSource.photo,
      readingLink: isKana ? null : readingLink,
      meaningLink: meaning,
      readQuality: ReadQuality(
        ocrConfidence: parts
            .map((f) => f.confidence)
            .reduce((a, b) => a < b ? a : b),
        corrected: parts.any((f) => f.corrected),
      ),
      headwordFragmentId: fragment.id,
      headwordNote: headwordNote,
    );
  }

  /// The dictionary's reading of the most likely entry: medium when every
  /// close candidate reads the same, low when they disagree (日: ひ, にち).
  ({String reading, PairLink link})? _dictionaryReading() {
    if (lemmas.isEmpty || lemmas.first.entry.readings.isEmpty) return null;
    final best = lemmas.first;
    final reading = best.entry.readings.first + printedSuffix;
    final close = {
      for (final l in lemmas)
        if (l.cost <= best.cost + 1.0 && l.entry.readings.isNotEmpty)
          _hiragana(l.entry.readings.first),
    };
    return (
      reading: reading,
      link: PairLink(
        confidence: close.length == 1
            ? PairConfidence.medium
            : PairConfidence.low,
        signals: const {PairSignal.dictionaryPair},
        note: close.length == 1 ? null : 'several dictionary readings',
      ),
    );
  }
}

/// The readings a reading cell prints (`あした/あす`, `ねん・とし`).
List<String> readingParts(String text) => [
  for (final r in text.split(RegExp('[/／・]')))
    if (r.trim().isNotEmpty) r.trim(),
];

String _hiragana(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r),
);

final class _Page {
  _Page(this.fragments, this.lexicon, {required this.hasLexicon})
    : segmenter = SentenceSegmenter(lexicon);

  List<Fragment> fragments;
  final _CachingLexicon lexicon;
  final bool hasLexicon;
  final SentenceSegmenter segmenter;
  final Deconjugator deconjugator = Deconjugator.standard;

  /// Median height of the Japanese lines of two letters or more (the
  /// page's type size); null when there is none.
  late final double? lineHeight = () {
    final heights = [
      for (final f in fragments)
        if (f.pass == OcrPass.japanese &&
            f.isJapanese &&
            f.text.runes.where((c) => isKana(c) || isKanji(c)).length >= 2)
          f.height,
    ]..sort();
    return heights.isEmpty ? null : heights[heights.length ~/ 2];
  }();

  /// Fragments that turned out to be sentences (unknown kanji runs the
  /// lattice splits into words).
  final Set<int> _asSentence = {};

  Iterable<Fragment> get _words => fragments.where(
    (f) => f.kind == FragmentKind.kanjiWord || f.kind == FragmentKind.kana,
  );

  Iterable<Fragment> get _sentences => fragments.where(
    (f) =>
        f.kind == FragmentKind.japaneseSentence || _asSentence.contains(f.id),
  );

  Future<void> prefetch() async {
    if (!hasLexicon) return;
    await lexicon.lookup({
      for (final f in _words) ...[
        for (final d in deconjugator.deconjugate(f.text)) d.base,
        if (f.kind == FragmentKind.kanjiWord)
          for (final v in lookalikeVariants(f.text))
            for (final d in deconjugator.deconjugate(v)) d.base,
        if (f.droppedPrefix case final prefix?)
          for (final d in deconjugator.deconjugate('$prefix${f.text}')) d.base,
        if (f.kind == FragmentKind.kana)
          for (final v in kanaLookalikeVariants(f.text))
            for (final d in deconjugator.deconjugate(v)) d.base,
        ...optionalPrefixForms(f.text),
        ...readingParts(f.text),
      ],
      for (final joined in splitHeadwordForms(fragments))
        for (final d in deconjugator.deconjugate(joined)) d.base,
      for (final f in fragments)
        if (f.kind == FragmentKind.japaneseSentence ||
            f.kind == FragmentKind.kanjiWord)
          ...segmenter.formsFor(f.text),
    });
  }

  /// A 口 or ロ taken off as a checkbox goes back when the longer text is a
  /// dictionary word and the rest is not, or is a rarer one (`ロッカー`,
  /// `口座` rather than `座`).
  void restoreBoxPrefixes() {
    if (!hasLexicon) return;
    bool restore(Fragment f, String prefix) {
      if (f.inlineReadingOf != null) return false;
      final whole = _lemmas('$prefix${f.text}');
      if (whole.isEmpty) return false;
      final rest = _lemmas(f.text);
      return rest.isEmpty || whole.first.cost < rest.first.cost;
    }

    fragments = List.unmodifiable([
      for (final f in fragments)
        if (f.droppedPrefix case final prefix? when restore(f, prefix))
          f.copyWith(text: '$prefix${f.text}', droppedPrefix: null)
        else
          f,
    ]);
  }

  List<Lemma> _lemmas(String text) {
    final candidates = [
      for (final d in deconjugator.deconjugate(text))
        // A word list prints dictionary forms (and な-adjectives with だ).
        if (d.tag == null || d.tag == 'adj-na' && d.steps.length == 1) d,
    ];
    return rankLemmas(candidates, {
      for (final d in candidates) d.base: lexicon.cached(d.base),
    });
  }

  /// Kanji-word fragments as items, keyed by fragment id.
  Map<int, _Item> headwords() {
    final inline = {
      for (final f in fragments)
        if (f.inlineReadingOf != null) f.inlineReadingOf!: f,
    };
    final out = <int, _Item>{};
    for (final f in fragments.where((f) => f.kind == FragmentKind.kanjiWord)) {
      final lemmas = hasLexicon ? _lemmasWithPrefix(f.text) : const <Lemma>[];
      if (lemmas.isEmpty && hasLexicon) {
        final fix = _lookalikeFix(f);
        if (fix != null) {
          out[f.id] = _Item(
            fix.fragment,
            fix.lemmas,
            inlineReading: inline[f.id],
            headwordNote: fix.note,
          );
          continue;
        }
      }
      if (hasLexicon &&
          lemmas.isEmpty &&
          inline[f.id] == null &&
          _splitsIntoWords(f.text)) {
        _asSentence.add(f.id);
        continue;
      }
      out[f.id] = _Item(
        f,
        lemmas,
        inlineReading: inline[f.id],
        headwordNote: _mendNotes[f.id],
      );
    }
    return out;
  }

  /// Why a mended fragment differs from what OCR read, by fragment id.
  final Map<int, String> _mendNotes = {};

  /// Joins kanji words a space split and mends kana-only headwords with a
  /// look-alike glyph, when a kana on the row reads the mended word.
  void mendHeadwords() {
    if (!hasLexicon) return;
    fragments = List.unmodifiable(joinSplitHeadwords(fragments, reads: _reads));
    final mends = mendKanaLookalikes(
      fragments,
      known: (t) => _lemmas(t).isNotEmpty || lexicon.cached(t).isNotEmpty,
      reads: _reads,
    );
    if (mends.isEmpty) return;
    fragments = List.unmodifiable([
      for (final f in fragments) mends[f.id]?.fragment ?? f,
    ]);
    for (final MapEntry(:key, :value) in mends.entries) {
      _mendNotes[key] = value.note;
    }
  }

  /// A kanji headword the kana on its row does not read, mended to the one
  /// spelling of that kana a kanji apart (`体む` beside やすむ → `休む`).
  Future<void> mendFromReadings() async {
    if (!hasLexicon) return;
    final mends = mendByReading(
      fragments,
      spellingsOf: (kana) => [
        for (final e in lexicon.cached(kana))
          if (e.isKanaForm) ...e.kanjiForms,
      ],
      reads: _reads,
    );
    if (mends.isEmpty) return;
    await lexicon.lookup({for (final m in mends.values) m.fragment.text});
    fragments = List.unmodifiable([
      for (final f in fragments) mends[f.id]?.fragment ?? f,
    ]);
    for (final MapEntry(:key, :value) in mends.entries) {
      _mendNotes[key] = value.note;
    }
  }

  /// [words] without the word-list words the page paired with nothing (no
  /// reading, no meaning from the photo: the next page cut at the edge, a
  /// kanji read out of a meaning line), when most word-list words of the
  /// page did pair. On a list of kanji words only (no readings or meanings
  /// printed) every word stays. The fragments go to the tray.
  List<ExtractedWord> withoutLonelyWords(List<ExtractedWord> words) {
    bool listed(ExtractedWord w) =>
        w.origin == WordOrigin.wordList &&
        w.headwordSource == FieldSource.photo;
    bool lonely(ExtractedWord w) {
      final reading = w.readingLink?.fragmentId;
      return listed(w) &&
          (reading == null || reading == w.headwordFragmentId) &&
          w.meaningLink?.fragmentId == null;
    }

    final list = words.where(listed).length;
    final alone = words.where(lonely).length;
    if (alone == 0 || (list - alone) < pairedShare * list) return words;
    return [
      for (final w in words)
        if (!lonely(w)) w,
    ];
  }

  /// [_lemmas], or for a word printed with an optional prefix in brackets
  /// (`(ご)飯`) those of its forms without the brackets.
  List<Lemma> _lemmasWithPrefix(String text) {
    final lemmas = _lemmas(text);
    if (lemmas.isNotEmpty) return lemmas;
    for (final form in optionalPrefixForms(text)) {
      final found = _lemmas(form);
      if (found.isNotEmpty) return found;
    }
    return lemmas;
  }

  /// One-syllable Korean-pass reads over the headword of a word (`트` over a
  /// headword both passes read): the Korean pass's garbage, not text left
  /// for the tray.
  Set<int> strayOverWords(Set<int> headwordIds) {
    final heads = [
      for (final id in headwordIds)
        if (id >= 0 && id < fragments.length) fragments[id],
    ];
    bool over(Fragment k, Fragment h) {
      final w =
          (k.right < h.right ? k.right : h.right) - (k.x > h.x ? k.x : h.x);
      final v =
          (k.bottom < h.bottom ? k.bottom : h.bottom) - (k.y > h.y ? k.y : h.y);
      return w > 0.5 * k.width && v > 0.5 * k.height;
    }

    return {
      for (final f in fragments)
        if (f.pass == OcrPass.korean &&
            f.kind == FragmentKind.hangul &&
            f.text.runes.where(isHangul).length <= 1 &&
            heads.any((h) => over(f, h)))
          f.id,
    };
  }

  /// The dictionary reads [headword] as every reading [kana] prints.
  bool _reads(String headword, String kana) {
    final lemmas = _lemmas(headword);
    if (lemmas.isEmpty) return false;
    final probe = Fragment(
      id: -1,
      text: headword,
      kind: FragmentKind.kanjiWord,
      x: 0,
      y: 0,
      width: 0,
      height: 0,
      pass: OcrPass.japanese,
    );
    return _Item(probe, lemmas).readsAs(kana);
  }

  /// An unknown headword that a look-alike glyph explains (`人ロ` read for
  /// `人口`): the dictionary word, only when the dictionary has it.
  ({Fragment fragment, List<Lemma> lemmas, String note})? _lookalikeFix(
    Fragment f,
  ) {
    for (final v in lookalikeVariants(f.text)) {
      final lemmas = _lemmas(v);
      if (lemmas.isEmpty) continue;
      final fixed = f.copyWith(text: v, corrected: true);
      fragments = List.unmodifiable([
        for (final g in fragments) g.id == f.id ? fixed : g,
      ]);
      return (
        fragment: fixed,
        lemmas: lemmas,
        note: '${f.text} → $v (글자 보정+사전)',
      );
    }
    return null;
  }

  /// [f] is the Japanese pass reading a Korean explanation paragraph: read
  /// below full confidence, not a bracketed word, inside (or just above or
  /// below) a Korean sentence box at least two lines tall in the same column.
  bool inKoreanParagraph(Fragment f) {
    if (f.pass != OcrPass.japanese || f.confidence >= 1.0 - 1e-6) return false;
    if (f.inlineReadingOf != null || _bracketed.contains(f.id)) return false;
    final reach = paragraphReach * f.height;
    return _paragraphs.any(
      (k) =>
          k.height >= paragraphMinLines * f.height &&
          f.cx >= k.x &&
          f.cx <= k.right &&
          f.cy >= k.y - reach &&
          f.cy <= k.bottom + reach,
    );
  }

  /// Fragments that are OCR garbage, not text to place by hand.
  bool isGarbage(Fragment f) =>
      f.pass == OcrPass.japanese &&
      f.isJapanese &&
      (atLowestConfidence(f.confidence) || inKoreanParagraph(f));

  late final List<Fragment> _paragraphs = [
    for (final f in fragments)
      if (f.pass == OcrPass.korean && f.kind == FragmentKind.koreanSentence) f,
  ];

  /// Headwords printed with a bracketed reading (`学校[がっこう]`).
  late final Set<int> _bracketed = {
    for (final f in fragments) ?f.inlineReadingOf,
  };

  bool _splitsIntoWords(String text) {
    final tokens = segmenter.segmentFound(text, lexicon.cached);
    return tokens.length >= 2 && tokens.every((t) => t.known);
  }

  /// [items] as the confidence step sees them.
  List<ConfidenceItem> confidenceItems(
    List<_Item> items,
    Map<int, double> slopes,
  ) {
    final slopeOf = _slopeLookup(items, slopes);
    return [
      for (final item in items)
        ConfidenceItem(
          fragment: item.fragment,
          headword: item.headword,
          isKana: item.isKana,
          readsAs: item.readsAs,
          namesMeaning: item.namesMeaning,
          glossForms: {item.headword, ?item.lemmas.firstOrNull?.base},
          glossReadings: item.glossReadings,
          slope: slopeOf(item),
        ),
    ];
  }

  /// Reading pairs and the row slopes they show.
  ({Map<int, PairLink> links, Set<int> used, Map<int, double> slopes})
  pairReadings(Map<int, _Item> heads, PairWeights w) {
    final links = <int, PairLink>{};
    final used = <int>{};
    final slopes = <int, double>{};
    for (final item in heads.values) {
      final r = item.inlineReading;
      if (r == null) continue;
      final agrees = !item.known || item.readsAs(r.text);
      links[item.fragment.id] = PairLink(
        confidence: agrees ? PairConfidence.high : PairConfidence.medium,
        signals: {
          PairSignal.inlineNotation,
          if (item.known && agrees) PairSignal.dictionaryPair,
          PairSignal.position,
        },
        fragmentId: r.id,
        note: agrees ? null : 'dictionary has another reading',
      );
      used.add(r.id);
    }
    final open = heads.values.where((h) => h.inlineReading == null).toList();
    final kana = fragments
        .where((f) => f.kind == FragmentKind.kana && f.inlineReadingOf == null)
        .toList();
    final cost = [
      for (final h in open) [for (final k in kana) _readingCost(h, k, w)],
    ];
    final assigned = assignMinimumCost(cost, unmatchedCost: w.readingUnmatched);
    for (final (i, column) in assigned.indexed) {
      if (column == null) continue;
      final h = open[i];
      final k = kana[column];
      final dict = h.known;
      final placement = readingPlacement(h.fragment, k);
      links[h.fragment.id] = PairLink(
        confidence: dict ? PairConfidence.medium : PairConfidence.low,
        signals: {
          if (dict) PairSignal.dictionaryPair,
          if (placement > 0) PairSignal.position,
        },
        fragmentId: k.id,
      );
      used.add(k.id);
      final dx = k.cx - h.fragment.cx;
      if (dx > 2 * h.fragment.height &&
          (k.cy - h.fragment.cy).abs() < 2 * h.fragment.height) {
        slopes[h.fragment.id] = (k.cy - h.fragment.cy) / dx;
      }
    }
    return (links: links, used: used, slopes: slopes);
  }

  double _readingCost(_Item h, Fragment k, PairWeights w) {
    final dict = h.known && h.readsAs(k.text);
    // The dictionary reads the headword otherwise.
    if (h.known && !dict) return double.infinity;
    // A kanji run no dictionary has (a misread headword) does not take, by
    // place alone, a kana the dictionary reads as other kanji words: that
    // kana is the reading of the headword OCR did not read.
    if (hasLexicon && !h.known && _readsOtherKanji(k)) return double.infinity;
    final placement = readingPlacement(h.fragment, k);
    if (!dict && placement < w.minReadingPosition) return double.infinity;
    return 1 -
        w.readingDictionary * (dict ? 1 : 0) -
        w.readingPosition * placement;
  }

  bool _readsOtherKanji(Fragment k) =>
      !isKatakana(k.text.runes.first) &&
      _kanjiWithReadings(readingParts(k.text)).isNotEmpty;

  /// Kana fragments that are words of their own (not a used reading).
  List<_Item> kanaWords(Set<int> usedReadings) => [
    for (final f in fragments)
      if (f.kind == FragmentKind.kana &&
          f.inlineReadingOf == null &&
          !usedReadings.contains(f.id))
        ?_kanaItem(f),
  ];

  _Item? _kanaItem(Fragment f) {
    if (!hasLexicon) return _Item(f, const []);
    // `(お)みやげ`: a kana headword as printed, looked up without brackets.
    final optional = optionalPrefixForms(f.text);
    if (optional.isNotEmpty) {
      return _Item(
        f,
        [for (final form in optional) ..._lemmas(form)].take(1).toList(),
      );
    }
    final lemmas = _lemmas(f.text);
    final asWord = lemmas
        // A kana word: an entry with no kanji or usually written in kana
        // (a katakana misread of a kanji word's reading is not one).
        .where((l) => l.entry.writtenInKana)
        .toList();
    // Kana that kanji words read as may be the reading of a headword OCR did
    // not read (`ねん/とし` gives the kanji with both readings); the meaning
    // decides (toWord).
    // Katakana is printed as such (サイン is not 死因).
    final candidates = isKatakana(f.text.runes.first)
        ? const <String, List<String>>{}
        : _kanjiWithReadings(readingParts(f.text));
    if (asWord.isNotEmpty || candidates.isNotEmpty) {
      return _Item(
        f,
        asWord,
        kanjiCandidates: candidates.keys.toList(),
        kanjiPos: candidates,
      );
    }
    // Unknown to the lexicon: maybe a loanword it lacks.
    return lemmas.isEmpty && lexicon.cached(f.text).isEmpty
        ? _Item(f, const [])
        : null;
  }

  /// Kanji forms the lexicon reads as every one of [readings], most
  /// frequent entry first.
  Map<String, List<String>> _kanjiWithReadings(List<String> readings) {
    if (readings.isEmpty) return const {};
    List<LexiconEntry> entries(String r) => [
      for (final e in lexicon.cached(r.trim()))
        if (e.isKanaForm && e.kanjiForms.isNotEmpty) e,
    ];
    final first = entries(readings.first)
      ..sort((a, b) => estimatedRank(a).compareTo(estimatedRank(b)));
    final others = [for (final r in readings.skip(1)) entries(r)];
    final out = <String, List<String>>{};
    for (final e in first) {
      for (final k in e.kanjiForms) {
        if (others.every((o) => o.any((x) => x.kanjiForms.contains(k)))) {
          out.putIfAbsent(k, () => e.partsOfSpeech);
        }
      }
    }
    return out;
  }

  Future<({Map<int, PairLink> links, Set<int> used})> pairMeanings(
    List<_Item> items,
    Map<int, double> slopes,
    KoreanGlossLookup? glosses,
    PairWeights w, {
    Set<int> withReading = const {},
  }) async {
    final glossOf = <int, List<String>>{};
    if (glosses != null) {
      for (final item in items) {
        final readings = [
          ...readingParts(item.inlineReading?.text ?? ''),
          ...?item.entry?.readings,
        ];
        // The printed form and its dictionary form (`丈夫だ` → `丈夫`), and
        // a word printed with an optional prefix without its brackets.
        final forms = {
          item.headword,
          ?item.lemmas.firstOrNull?.base,
          ...optionalPrefixForms(item.headword),
        };
        glossOf[item.fragment.id] = [
          for (final h in forms) ...await glosses(h, readings),
        ];
      }
    }
    final slopeOf = _slopeLookup(items, slopes);
    fragments = List.unmodifiable(
      settleGluedBadges(
        fragments,
        named: (k, text) => items.any(
          (item) =>
              meaningPlacement(
                    item.fragment,
                    k,
                    slope: slopeOf(item),
                    rowTolerance: w.rowTolerance,
                  ) >
                  0 &&
              _names(item, text, glossOf[item.fragment.id]),
        ),
      ),
    );
    _promoteShortPredicates();
    final korean = fragments
        .where((f) => f.kind == FragmentKind.hangul)
        .toList();
    final signals = <(int, int), Set<PairSignal>>{};
    final cost = [
      for (final item in items)
        [
          for (final k in korean)
            _meaningCost(
              item,
              k,
              slopeOf(item),
              glossOf[item.fragment.id],
              w,
              (s) => signals[(item.fragment.id, k.id)] = s,
              unconfirmed: _unconfirmed(item, withReading),
            ),
        ],
    ];
    final assigned = assignMinimumCost(cost, unmatchedCost: w.meaningUnmatched);
    final links = <int, PairLink>{};
    final used = <int>{};
    for (final (i, column) in assigned.indexed) {
      if (column == null) continue;
      final item = items[i];
      final k = korean[column];
      final s = signals[(item.fragment.id, k.id)] ?? const {};
      final content = s.where((x) => x != PairSignal.position).length;
      links[item.fragment.id] = PairLink(
        confidence: content >= 2
            ? PairConfidence.high
            : content == 1
            ? PairConfidence.medium
            : PairConfidence.low,
        signals: s,
        fragmentId: k.id,
      );
      used.add(k.id);
    }
    return (links: links, used: used);
  }

  /// Row tilt for an item: its own reading's, else the nearest item's.
  double Function(_Item) _slopeLookup(
    List<_Item> items,
    Map<int, double> slopes,
  ) {
    final measured = [
      for (final item in items)
        if (slopes[item.fragment.id] case final s?) (item.fragment, s),
    ];
    return (item) {
      final own = slopes[item.fragment.id];
      if (own != null) return own;
      if (measured.isEmpty) return 0;
      var best = measured.first;
      for (final m in measured) {
        if ((m.$1.cy - item.fragment.cy).abs() <
            (best.$1.cy - item.fragment.cy).abs()) {
          best = m;
        }
      }
      return (best.$1.cy - item.fragment.cy).abs() <= 6 * item.fragment.height
          ? best.$2
          : 0;
    };
  }

  /// A kanji headword read at the engine's lowest confidence that no
  /// reading on the page confirms: often a misread of the real headword
  /// (`竹` read for `箱` beside はこ), so a kana beside it wins a tie for the
  /// meaning.
  bool _unconfirmed(_Item item, Set<int> withReading) =>
      hasLexicon &&
      !item.isKana &&
      item.inlineReading == null &&
      atLowestConfidence(item.fragment.confidence) &&
      !withReading.contains(item.fragment.id);

  /// A content signal of [item] names [korean]: the Korean reading of its
  /// kanji or its Korean gloss, as the pairing counts them.
  bool _names(_Item item, String korean, List<String>? glosses) {
    final hanja = item.kanjiCandidates.isNotEmpty
        ? item.kanjiNaming(korean) != null
        : !item.isKana &&
              (hanjaMatchLength(item.headword, korean) >= minHanjaSyllables ||
                  hanjaNamesWord(item.headword, korean));
    return hanja || (glosses != null && _glossMatches(glosses, korean));
  }

  /// Japanese sentences that give words and take translations.
  List<Fragment> get _readSentences => [
    for (final s in _sentences)
      if (!atLowestConfidence(s.confidence) &&
          !inKoreanParagraph(s) &&
          !isPattern(s.text))
        s,
  ];

  /// A Korean "sentence" that is short dictionary-form predicates and no
  /// Japanese sentence could take as its translation is a meaning read with
  /// a full stop after it (`기다리다.`).
  void _promoteShortPredicates() {
    final sentences = _readSentences;
    fragments = List.unmodifiable([
      for (final f in fragments)
        if (f.kind == FragmentKind.koreanSentence &&
            isShortPredicate(f.text) &&
            !sentences.any((s) => translationPlacement(s, f) > 0))
          f.copyWith(
            kind: FragmentKind.hangul,
            text: predicateMeaning(f.text),
            corrected: true,
          )
        else
          f,
    ]);
  }

  double _meaningCost(
    _Item item,
    Fragment k,
    double slope,
    List<String>? glosses,
    PairWeights w,
    void Function(Set<PairSignal>) record, {
    bool unconfirmed = false,
  }) {
    final hanja = item.kanjiCandidates.isNotEmpty
        ? item.kanjiNaming(k.text) != null
        : !item.isKana &&
              (hanjaMatchLength(item.headword, k.text) >= minHanjaSyllables ||
                  hanjaNamesWord(item.headword, k.text));
    final gloss = glosses != null && _glossMatches(glosses, k.text);
    final placement = meaningPlacement(
      item.fragment,
      k,
      slope: slope,
      rowTolerance: w.rowTolerance,
    );
    final content = (hanja ? 1 : 0) + (gloss ? 1 : 0);
    // Far from the item, one content signal is not enough (a heading word
    // spelled inside another item's meaning).
    if (placement == 0 && content < 2) return double.infinity;
    if (content == 0) {
      if (placement < w.minMeaningPosition) return double.infinity;
      // An unknown kanji run with no reading pairs on content only.
      if (hasLexicon &&
          !item.known &&
          !item.isKana &&
          item.inlineReading == null) {
        return double.infinity;
      }
    }
    record({
      if (hanja) PairSignal.hanjaReading,
      if (gloss) PairSignal.koreanGloss,
      if (placement >= w.minMeaningPosition) PairSignal.position,
    });
    return 1 -
        w.meaningHanja * (hanja ? 1 : 0) -
        w.meaningGloss * (gloss ? 1 : 0) -
        w.meaningPosition * placement +
        (unconfirmed && content == 0 ? w.unconfirmedPenalty : 0);
  }

  /// Words of every sentence, with the sentence and its translation.
  ({List<ExtractedWord> words, Set<int> used}) sentenceWords(
    Set<int> usedKorean,
    PairWeights w,
  ) {
    // The engine's lowest confidence: a sentence read out of a Korean
    // paragraph's garbage, not a printed sentence. Left out before the
    // translations are assigned, so it takes none.
    final sentences = _readSentences;
    final korean = fragments
        .where(
          (f) =>
              f.kind == FragmentKind.koreanSentence ||
              (f.kind == FragmentKind.hangul && !usedKorean.contains(f.id)),
        )
        .toList();
    final cost = [
      for (final s in sentences)
        [
          for (final k in korean)
            switch (translationPlacement(s, k)) {
              0 => double.infinity,
              final p => 1 - w.translationPosition * p,
            },
        ],
    ];
    final assigned = assignMinimumCost(
      cost,
      unmatchedCost: w.translationUnmatched,
    );
    final words = <ExtractedWord>[];
    final used = <int>{};
    for (final (i, s) in sentences.indexed) {
      final translation = assigned[i] == null ? null : korean[assigned[i]!];
      final tokens = hasLexicon
          ? [
              for (final t in SentenceSegmenter.onlyContent(
                segmenter.segmentFound(s.text, lexicon.cached),
              ))
                if (_isSentenceWord(t, s.text)) t,
            ]
          : const <LatticeToken>[];
      if (tokens.isEmpty) continue;
      used.add(s.id);
      if (translation != null) used.add(translation.id);
      for (final t in tokens) {
        final kana = t.base.runes.every(isKana);
        words.add(
          ExtractedWord(
            headword: t.base,
            origin: WordOrigin.sentence,
            readings: kana || t.readings.isEmpty
                ? const []
                : [t.readings.first],
            partsOfSpeech: t.partsOfSpeech,
            readingSource: kana || t.readings.isEmpty
                ? null
                : FieldSource.dictionary,
            readingLink: kana || t.readings.isEmpty
                ? null
                : const PairLink(
                    confidence: PairConfidence.medium,
                    signals: {PairSignal.dictionaryPair},
                  ),
            readQuality: ReadQuality(
              ocrConfidence: s.confidence,
              corrected: s.corrected,
            ),
            example: WordExample(ja: s.text, ko: translation?.text),
            headwordFragmentId: s.id,
          ),
        );
      }
    }
    return (words: words, used: used);
  }
}

/// A word of a sentence the learner would study: not one kana (a stray
/// glyph or an ending), not a reading printed in brackets (`［がっこう］`).
bool _isSentenceWord(LatticeToken t, String sentence) {
  final kana = t.surface.runes.every(isKana);
  if (kana && t.base.runes.length == 1) return false;
  if (!kana) return true;
  final runes = sentence.runes.toList();
  final before = t.start > 0 ? runes[t.start - 1] : null;
  final after = t.end < runes.length ? runes[t.end] : null;
  return !(_openers.contains(before) || _closers.contains(after));
}

final Set<int> _openers = '[［【「『(（'.runes.toSet();
final Set<int> _closers = ']］】」』)）'.runes.toSet();

/// A pattern line (`〜は〜です。`): its words are placeholders, not text.
bool isPattern(String text) =>
    text.contains('〜') || text.contains('～') || text.contains('~');

/// Korean sentence boxes at least this many of the fragment's lines tall
/// are a paragraph (one box over several lines).
const double paragraphMinLines = 1.8;

/// How far above or below a paragraph box, in the fragment's line heights,
/// a line still belongs to it (the Korean pass missed its last lines).
const double paragraphReach = 2.0;

/// [text] with each lone look-alike katakana inside a kanji word swapped for
/// its kanji (`人ロ` → `人口`), fewest changes first; empty when there is
/// nothing to swap. Katakana next to katakana is a word (`ローマ字`).
List<String> lookalikeVariants(String text) {
  final runes = text.runes.toList();
  if (!runes.any(isKanji)) return const [];
  bool lone(int i) =>
      (i == 0 || !isKatakana(runes[i - 1])) &&
      (i == runes.length - 1 || !isKatakana(runes[i + 1]));
  final spots = [
    for (var i = 0; i < runes.length; i++)
      if (confusableInKanji.containsKey(runes[i]) && lone(i)) i,
  ];
  if (spots.isEmpty || spots.length > maxLookalikes) return const [];
  final out = <List<int>>[];
  for (var mask = 1; mask < 1 << spots.length; mask++) {
    final v = [...runes];
    for (var b = 0; b < spots.length; b++) {
      if (mask & (1 << b) != 0) {
        v[spots[b]] = confusableInKanji[runes[spots[b]]]!;
      }
    }
    out.add(v);
  }
  int changes(List<int> v) => [
    for (var i = 0; i < v.length; i++) v[i] != runes[i],
  ].where((c) => c).length;
  out.sort((a, b) => changes(a).compareTo(changes(b)));
  return [for (final v in out) String.fromCharCodes(v)];
}

/// Below this share of the page's word-list words paired with a reading or
/// meaning, the page is a bare list and unpaired words stay words.
const double pairedShare = 0.5;

/// More look-alike glyphs than this in one headword: not a misread word.
const int maxLookalikes = 3;

bool _glossMatches(List<String> glosses, String korean) {
  final parts = korean
      .split(RegExp(r'[,，、/·;]+'))
      .map(_bare)
      .where((p) => p.isNotEmpty)
      .toList();
  for (final g in glosses.map(_bare)) {
    if (g.isEmpty) continue;
    if (parts.any((p) => p == g || p.startsWith(g))) return true;
  }
  return false;
}

String _bare(String s) => s.replaceAll(RegExp(r'\([^)]*\)|[^가-힣]'), '');

/// A headword as one word: a な-adjective's printed だ does not count
/// (`丈夫だ` from a word list and `丈夫` from a sentence are one word).
String headwordKey(String headword) =>
    headword.length > 1 && headword.endsWith('だ') && headword.runes.any(isKanji)
    ? headword.substring(0, headword.length - 1)
    : headword;

bool _isKnown(String headword, Set<String> known) =>
    known.contains(headword) ||
    known.map(headwordKey).contains(headwordKey(headword));

/// One word per headword: a printed word beats a sentence word (and takes
/// its example); of two printed ones the better paired stays.
List<ExtractedWord> _merge(List<ExtractedWord> words) {
  final byHeadword = <String, int>{}; // by headwordKey
  final out = <ExtractedWord>[];
  for (final w in words) {
    final i = byHeadword[headwordKey(w.headword)];
    if (i == null) {
      byHeadword[headwordKey(w.headword)] = out.length;
      out.add(w);
      continue;
    }
    final kept = out[i];
    out[i] = _better(kept, w);
  }
  return out;
}

ExtractedWord _better(ExtractedWord a, ExtractedWord b) {
  if (a.origin != b.origin) {
    final printed = a.origin == WordOrigin.wordList ? a : b;
    final sentence = a.origin == WordOrigin.wordList ? b : a;
    return printed.example == null
        ? printed.copyWith(example: sentence.example)
        : printed;
  }
  int score(ExtractedWord w) =>
      (w.meaning == null ? 0 : 4) +
      w.pairConfidence.index +
      (w.readingSource == FieldSource.photo ? 1 : 0);
  return score(b) > score(a) ? b : a;
}

/// A word whose headword the page did not settle (several dictionary
/// spellings for its kana, offered as candidates) is never high: the
/// learner picks the headword.
ExtractedWord _unsettledHeadword(ExtractedWord w) {
  if (w.headwordCandidates.isEmpty) return w;
  PairLink? belowHigh(PairLink? link) =>
      link == null || link.confidence != PairConfidence.high
      ? link
      : PairLink(
          confidence: PairConfidence.medium,
          signals: link.signals,
          fragmentId: link.fragmentId,
          note: '표제어 후보 ${w.headwordCandidates.length}',
        );
  return w.copyWith(
    readingLink: belowHigh(w.readingLink),
    meaningLink: belowHigh(w.meaningLink),
  );
}
