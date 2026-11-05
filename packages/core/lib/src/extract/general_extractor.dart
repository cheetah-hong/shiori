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

import 'package:shiori_core/src/extract/deconjugator.dart';
import 'package:shiori_core/src/extract/extracted_word.dart';
import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/extract/fragment_collector.dart';
import 'package:shiori_core/src/extract/hanja.dart';
import 'package:shiori_core/src/extract/hungarian.dart';
import 'package:shiori_core/src/extract/lattice.dart';
import 'package:shiori_core/src/extract/pairing.dart';
import 'package:shiori_core/src/extract/script_runs.dart';
import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// Korean words a dictionary gives for a headword (a Korean gloss block
/// plugs in here); empty when it knows none.
typedef KoreanGlossLookup =
    Future<List<String>> Function(String headword, List<String> readings);

/// A kanji readings match needs this many Korean syllables (one syllable
/// matches by chance too often).
const int minHanjaSyllables = 2;

/// Japanese sentences read at this OCR confidence or lower give no words
/// (Apple Vision gives 0.3 to lines it barely made out).
const double lowestSentenceConfidence = 0.3;

/// OCR scan → fragments → headword, reading and meaning pairing → words.
///
/// Sentences become dictionary-form words with the sentence as their example.
final class GeneralExtractor {
  GeneralExtractor({
    this.lexicon = const EmptyLexicon(),
    this.koreanGlosses,
    this.weights = const PairWeights(),
  });

  final Lexicon lexicon;
  final KoreanGlossLookup? koreanGlosses;
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
    await page.prefetch();
    page.restoreBoxPrefixes();
    final heads = page.headwords();
    final readings = page.pairReadings(heads, weights);
    final items = [...heads.values, ...page.kanaWords(readings.used)];
    final meanings = await page.pairMeanings(
      items,
      readings.slopes,
      koreanGlosses,
      weights,
    );
    final sentenceWords = page.sentenceWords(meanings.used, weights);
    final words = _merge([
      for (final item in items)
        if (item.isWord(
          page.hasLexicon,
          meanings.links[item.fragment.id],
          reading: readings.links[item.fragment.id],
        ))
          item.toWord(
            readings.links[item.fragment.id],
            meanings.links[item.fragment.id],
            fragments,
          ),
      ...sentenceWords.words,
    ]).where((w) => !_isKnown(w.headword, knownHeadwords)).toList();
    final used = <int>{
      ...readings.used,
      ...meanings.used,
      ...sentenceWords.used,
      for (final w in words) ?w.headwordFragmentId,
      for (final f in fragments)
        if (f.inlineReadingOf != null) f.id,
    };
    // Heads of known words that were dropped still count as used.
    for (final item in items) {
      if (_isKnown(item.headword, knownHeadwords)) used.add(item.fragment.id);
    }
    return ExtractionResult(
      words: List.unmodifiable(words),
      unpaired: List.unmodifiable([
        for (final f in fragments)
          if (f.isContent && !used.contains(f.id)) f,
      ]),
      fragments: List.unmodifiable(fragments),
      elapsed: watch.elapsed,
    );
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
  });

  final Fragment fragment;

  /// Dictionary forms the lexicon confirms, best first (empty: unknown).
  final List<Lemma> lemmas;
  final Fragment? inlineReading;

  /// For kana the lexicon knows only as the reading of kanji words (a
  /// headword OCR did not read): those kanji forms, most frequent first.
  final List<String> kanjiCandidates;

  /// POS codes of each of [kanjiCandidates].
  final Map<String, List<String>> kanjiPos;

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

  bool isWord(bool hasLexicon, PairLink? meaning, {PairLink? reading}) {
    if (isOrphanReading) return meaning != null;
    // Read at the engine's lowest confidence and paired with nothing: the
    // Japanese pass's garbage over Korean text more often than a word.
    if (hasLexicon &&
        fragment.confidence <= lowestSentenceConfidence &&
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
      partsOfSpeech: entry?.partsOfSpeech ?? const [],
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
        if (f.droppedPrefix case final prefix?)
          for (final d in deconjugator.deconjugate('$prefix${f.text}')) d.base,
        ...readingParts(f.text),
      ],
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
      final lemmas = hasLexicon ? _lemmas(f.text) : const <Lemma>[];
      if (hasLexicon &&
          lemmas.isEmpty &&
          inline[f.id] == null &&
          _splitsIntoWords(f.text)) {
        _asSentence.add(f.id);
        continue;
      }
      out[f.id] = _Item(f, lemmas, inlineReading: inline[f.id]);
    }
    return out;
  }

  bool _splitsIntoWords(String text) {
    final tokens = segmenter.segmentFound(text, lexicon.cached);
    return tokens.length >= 2 && tokens.every((t) => t.known);
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
    final placement = readingPlacement(h.fragment, k);
    if (!dict && placement < w.minReadingPosition) return double.infinity;
    return 1 -
        w.readingDictionary * (dict ? 1 : 0) -
        w.readingPosition * placement;
  }

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
    PairWeights w,
  ) async {
    final korean = fragments
        .where((f) => f.kind == FragmentKind.hangul)
        .toList();
    final glossOf = <int, List<String>>{};
    if (glosses != null) {
      for (final item in items) {
        final readings = [
          ...readingParts(item.inlineReading?.text ?? ''),
          ...?item.entry?.readings,
        ];
        // The printed form and its dictionary form (`丈夫だ` → `丈夫`).
        final forms = {item.headword, ?item.lemmas.firstOrNull?.base};
        glossOf[item.fragment.id] = [
          for (final h in forms) ...await glosses(h, readings),
        ];
      }
    }
    final slopeOf = _slopeLookup(items, slopes);
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

  double _meaningCost(
    _Item item,
    Fragment k,
    double slope,
    List<String>? glosses,
    PairWeights w,
    void Function(Set<PairSignal>) record,
  ) {
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
        w.meaningPosition * placement;
  }

  /// Words of every sentence, with the sentence and its translation.
  ({List<ExtractedWord> words, Set<int> used}) sentenceWords(
    Set<int> usedKorean,
    PairWeights w,
  ) {
    // The engine's lowest confidence: a sentence read out of a Korean
    // paragraph's garbage, not a printed sentence. Left out before the
    // translations are assigned, so it takes none.
    final sentences = [
      for (final s in _sentences)
        if (s.confidence > lowestSentenceConfidence) s,
    ];
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
          ? SentenceSegmenter.onlyContent(
              segmenter.segmentFound(s.text, lexicon.cached),
            )
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
