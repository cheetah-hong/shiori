/// The pairing confidence after the words are merged (docs/extraction.md,
/// 4.4): a reading or a meaning backed by one content signal and a strong
/// placement becomes high when nothing nearby could take the same pair, and
/// any high pairing is lowered when its cell or headword is doubtful. A
/// fragment read at the engine's lowest confidence keeps its pair below high
/// unless the word's other pair backs it (a dictionary reading beside a
/// meaning its kanji or Korean gloss names).
///
/// Only the confidence (and the note saying why) changes: which fragment
/// pairs with which headword, and every value, stay as the extractor made
/// them. It runs after merging so the merge's choice between two words of
/// one headword does not depend on it.
library;

import 'package:shiori_core/src/extract/extracted_word.dart';
import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/extract/general_extractor.dart';
import 'package:shiori_core/src/extract/hanja.dart';
import 'package:shiori_core/src/extract/pairing.dart';
import 'package:shiori_core/src/extract/read_back.dart';
import 'package:shiori_core/src/extract/script_runs.dart';

/// A reading needs at least this placement to be high: on the headword's
/// row within 0.6 of its line height, furigana above, or right below.
const double strongReadingPlacement = 0.6;

/// A meaning with one content signal needs at least this placement: after
/// the row tilt, within 0.9 of the headword's line height.
const double strongMeaningPlacement = 0.85;

/// A meaning taller than this many headword lines was joined from several
/// lines: its other lines are unchecked.
const double maxMeaningLines = 1.5;

/// A headword or kana word of the page, as the confidence step sees it.
final class ConfidenceItem {
  const ConfidenceItem({
    required this.fragment,
    required this.headword,
    required this.isKana,
    required this.readsAs,
    required this.namesMeaning,
    required this.glossForms,
    required this.glossReadings,
    required this.slope,
  });

  final Fragment fragment;
  final String headword;
  final bool isKana;

  /// Every reading the text prints is one the dictionary gives the headword.
  final bool Function(String text) readsAs;

  /// The Korean text spells the headword's kanji in Korean readings.
  final bool Function(String korean) namesMeaning;

  /// Forms and readings the Korean gloss lookup is asked with.
  final Set<String> glossForms;
  final List<String> glossReadings;

  /// The row tilt the meaning placement is measured with.
  final double slope;
}

/// [words] with their pairing confidence settled against the [items] and
/// [fragments] of the page. [glosses] is the gloss lookup the pairing used.
/// [taken]: the fragments the page's word-list words took (headwords,
/// readings, meanings, read-back traces), also of words merged away or left
/// out as known; without it they are gathered from [words].
Future<List<ExtractedWord>> settleConfidence(
  List<ExtractedWord> words, {
  required List<Fragment> fragments,
  required List<ConfidenceItem> items,
  KoreanGlossLookup? glosses,
  Set<int>? taken,
}) async {
  // What the word-list words took. A kanji run the lattice split into
  // sentence words (`陸りる` → 陸) is still a failed headword read.
  final used = <int>{
    ...?taken,
    if (taken == null)
      for (final w in words)
        if (w.origin == WordOrigin.wordList) ...[
          ?w.headwordFragmentId,
          ?w.readingLink?.fragmentId,
          ?w.meaningLink?.fragmentId,
        ],
    for (final f in fragments) ?f.inlineReadingOf,
  };
  final settle = _Settle(fragments, items, glosses, used);
  return [for (final w in words) await settle.word(w)];
}

/// A pair as the rules left it, and whether the only thing that kept it
/// below high is a fragment read at the engine's lowest confidence.
typedef _Judged = (PairLink?, bool);

final class _Settle {
  _Settle(this.fragments, this.items, this.glosses, this.used)
    : byId = {for (final i in items) i.fragment.id: i};

  /// Fragments the page's words took.
  final Set<int> used;

  final List<Fragment> fragments;
  final List<ConfidenceItem> items;
  final Map<int, ConfidenceItem> byId;
  final KoreanGlossLookup? glosses;
  final Map<int, List<String>> _glossWords = {};

  Future<ExtractedWord> word(ExtractedWord w) async {
    if (w.origin != WordOrigin.wordList) return w;
    final item = w.headwordFragmentId == null
        ? null
        : byId[w.headwordFragmentId];
    final fromPage = w.headwordSource == FieldSource.photo;
    final (reading, meaning) = _backed(
      item,
      _reading(w, item, fromPage),
      await _meaning(w, item, fromPage),
    );
    return identical(reading, w.readingLink) &&
            identical(meaning, w.meaningLink)
        ? w
        : w.copyWith(readingLink: reading, meaningLink: meaning);
  }

  /// Pairs held back only by a fragment read at the engine's lowest
  /// confidence are high when the word's other pair backs them
  /// ([_corroborated]); else they stay as they are, with [faintReadNote].
  (PairLink?, PairLink?) _backed(
    ConfidenceItem? item,
    _Judged reading,
    _Judged meaning,
  ) {
    final (r, rFaint) = reading;
    final (m, mFaint) = meaning;
    if (!rFaint && !mFaint) return (r, m);
    PairLink? raised(PairLink? l, bool faint) =>
        faint && l != null ? _raised(l) : l;
    final (highR, highM) = (raised(r, rFaint), raised(m, mFaint));
    if (_corroborated(item, highR, highM)) return (highR, highM);
    PairLink? noted(PairLink? l, bool faint) =>
        faint && l != null ? _note(l, faintReadNote) : l;
    return (noted(r, rFaint), noted(m, mFaint));
  }

  /// A dictionary reading beside a meaning the headword's kanji or Korean
  /// gloss names, both high and the meaning in its strong placement: two
  /// content signals of their own, which a faint misread rarely meets.
  bool _corroborated(
    ConfidenceItem? item,
    PairLink? reading,
    PairLink? meaning,
  ) {
    if (item == null || reading == null || meaning == null) return false;
    if (reading.confidence != PairConfidence.high ||
        meaning.confidence != PairConfidence.high ||
        !reading.signals.contains(PairSignal.dictionaryPair) ||
        !meaning.signals.any(
          (s) => s == PairSignal.hanjaReading || s == PairSignal.koreanGloss,
        )) {
      return false;
    }
    final id = meaning.fragmentId;
    if (id == null || id < 0 || id >= fragments.length) return false;
    return meaningPlacement(item.fragment, fragments[id], slope: item.slope) >=
        strongMeaningPlacement;
  }

  _Judged _reading(ExtractedWord w, ConfidenceItem? item, bool fromPage) {
    final link = w.readingLink;
    if (link == null) return (null, false);
    if (!fromPage) return (_atMost(link, '사전이 준 표제어'), false);
    if (link.confidence == PairConfidence.high ||
        item == null ||
        w.readingSource != FieldSource.photo ||
        link.signals.contains(PairSignal.inlineNotation) ||
        !link.signals.contains(PairSignal.dictionaryPair)) {
      return (link, false);
    }
    final id = link.fragmentId;
    if (id == null || id < 0 || id >= fragments.length) return (link, false);
    final head = item.fragment;
    final kana = fragments[id];
    if (!item.readsAs(kana.text) ||
        readingPlacement(head, kana) < strongReadingPlacement) {
      return (link, false);
    }
    final rival = items.any(
      (o) =>
          !o.isKana &&
          o.fragment.id != head.id &&
          o.headword != item.headword &&
          readingPlacement(o.fragment, kana) > 0 &&
          o.readsAs(kana.text),
    );
    if (rival) return (_note(link, '이웃 표제어도 같은 읽기'), false);
    final another = fragments.any(
      (f) =>
          f.kind == FragmentKind.kana &&
          f.inlineReadingOf == null &&
          f.id != kana.id &&
          readingPlacement(head, f) > 0 &&
          item.readsAs(f.text),
    );
    if (another) return (_note(link, '근처에 다른 읽기'), false);
    final faint =
        atLowestConfidence(head.confidence) ||
        atLowestConfidence(kana.confidence);
    return (faint ? link : _raised(link), faint);
  }

  Future<_Judged> _meaning(
    ExtractedWord w,
    ConfidenceItem? item,
    bool fromPage,
  ) async {
    final link = w.meaningLink;
    if (link == null) return (null, false);
    if (!fromPage) return (_atMost(link, '사전이 준 표제어'), false);
    if (_lostHeadword(w)) {
      return (
        _note(_atMost(link, _lostHeadwordNote), _lostHeadwordNote),
        false,
      );
    }
    if (w.meaningSource != FieldSource.photo) return (link, false);
    final id = link.fragmentId;
    if (id == null || id < 0 || id >= fragments.length) return (link, false);
    final korean = fragments[id];
    if (!plainMeaning(korean.text)) {
      return (_atMost(link, '뜻에 한글이 아닌 글자'), false);
    }
    if (w.readings.isEmpty && w.headword.runes.any(isKanji)) {
      return (_atMost(link, '읽기 없음'), false);
    }
    if (link.confidence == PairConfidence.high || item == null) {
      return (link, false);
    }
    final content = link.signals
        .where(
          (s) => s == PairSignal.hanjaReading || s == PairSignal.koreanGloss,
        )
        .length;
    if (content != 1) return (link, false);
    final head = item.fragment;
    final named =
        link.signals.contains(PairSignal.hanjaReading) ||
        glossNames(await _glossesOf(item), korean.text);
    if (!named ||
        meaningPlacement(head, korean, slope: item.slope) <
            strongMeaningPlacement ||
        korean.height > maxMeaningLines * head.height) {
      return (link, false);
    }
    final same = fragments.any(
      (f) =>
          f.kind == FragmentKind.hangul &&
          f.id != korean.id &&
          _bare(f.text).isNotEmpty &&
          _bare(f.text) == _bare(korean.text) &&
          meaningPlacement(head, f, slope: item.slope) > 0,
    );
    if (same) return (_note(link, '이웃에 같은 뜻'), false);
    for (final o in items) {
      if (o.fragment.id == head.id || o.headword == item.headword) continue;
      if (meaningPlacement(o.fragment, korean, slope: o.slope) <= 0) continue;
      if (o.namesMeaning(korean.text) ||
          glossNames(await _glossesOf(o), korean.text, prefix: true)) {
        return (_note(link, '이웃 표제어도 같은 뜻'), false);
      }
    }
    final faint =
        atLowestConfidence(head.confidence) ||
        atLowestConfidence(korean.confidence);
    return (faint ? link : _raised(link), faint);
  }

  /// A kana word left where OCR lost the headword (its kanji were not read
  /// back): the kana may not be what the page prints.
  bool _lostHeadword(ExtractedWord w) {
    final id = w.headwordFragmentId;
    if (w.readings.isNotEmpty ||
        id == null ||
        id < 0 ||
        id >= fragments.length) {
      return false;
    }
    final kana = fragments[id];
    return kana.kind == FragmentKind.kana &&
        kana.text == w.headword &&
        hasHeadwordTrace(kana, fragments, used);
  }

  Future<List<String>> _glossesOf(ConfidenceItem item) async {
    final g = glosses;
    if (g == null) return const [];
    final known = _glossWords[item.fragment.id];
    if (known != null) return known;
    return _glossWords[item.fragment.id] = [
      for (final form in item.glossForms) ...await g(form, item.glossReadings),
    ];
  }
}

const String _lostHeadwordNote = '표제어 자리 판독 실패';

/// Why a pair stays below high when the only thing against it is a
/// fragment read at the engine's lowest confidence and the word's other
/// pair does not back it.
const String faintReadNote = '글자가 흐릿하게 읽힘';

/// [link] made high, with a placement signal.
PairLink _raised(PairLink link) => PairLink(
  confidence: PairConfidence.high,
  signals: {...link.signals, PairSignal.position},
  fragmentId: link.fragmentId,
);

/// [link] lowered to medium when it was high, with [why].
PairLink _atMost(PairLink link, String why) =>
    link.confidence == PairConfidence.high
    ? PairLink(
        confidence: PairConfidence.medium,
        signals: link.signals,
        fragmentId: link.fragmentId,
        note: why,
      )
    : link;

/// [link] as it is, with [why] it is not higher.
PairLink _note(PairLink link, String why) => PairLink(
  confidence: link.confidence,
  signals: link.signals,
  fragmentId: link.fragmentId,
  note: link.note ?? why,
);

final RegExp _notes = RegExp(r'\([^()]*\)|（[^（）]*）');
final RegExp _plainPart = RegExp(r'^(?:[가-힣]+(?: [가-힣]+)*|[0-9]+)$');

/// [meaning] (its bracketed notes left out) is Korean words or numbers
/// between commas and nothing else: no OCR debris a content signal could
/// not vouch for (`명4, 사`, `몀. 산`).
bool plainMeaning(String meaning) {
  final text = meaning.replaceAll(_notes, '').trim();
  if (text.isEmpty) return false;
  return text.split(RegExp('[,，]')).every((p) => _plainPart.hasMatch(p.trim()));
}

/// One of [glosses] is a whole word of [korean] (or that word with 하다 or
/// 되다 after it). With [prefix], the start of a word is enough, as the
/// pairing counts it.
bool glossNames(List<String> glosses, String korean, {bool prefix = false}) {
  final parts = [
    for (final p in korean.split(RegExp(r'[,，、/·;]+')))
      if (_bare(p).isNotEmpty) _bare(p),
  ];
  for (final g in glosses.map(_bare)) {
    if (g.isEmpty) continue;
    for (final p in parts) {
      if (p == g || p == '$g하다' || p == '$g되다') return true;
      if (prefix && p.startsWith(g)) return true;
    }
  }
  return false;
}

/// The Korean text spells [headword]'s kanji in Korean readings (as the
/// pairing counts it).
bool hanjaNamesMeaning(String headword, String korean) =>
    hanjaMatchLength(headword, korean) >= minHanjaSyllables ||
    hanjaNamesWord(headword, korean);

String _bare(String s) => s.replaceAll(RegExp(r'\([^)]*\)|[^가-힣]'), '');
