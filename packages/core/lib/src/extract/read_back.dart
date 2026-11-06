/// Headwords OCR did not read, read back from their kana and meaning.
///
/// A word list row whose headword OCR missed leaves its kana and its Korean
/// meaning, and where the headword was printed, a trace of the failed read:
/// a Japanese fragment that became nothing (a 0.3 line, a kanji run no
/// dictionary has), one stray Korean syllable, or a lone 口/ロ. When the
/// Korean glossary read backwards has exactly one kanji spelling of the kana
/// whose Korean words name the meaning, that spelling is the headword
/// (source: dictionary). With two or more the kana stays and they are
/// offered as candidates. Without a trace nothing changes: a kana headword
/// printed as such (`たくさん`) stays kana even when its meaning has one
/// kanji spelling. What OCR read of the checkbox column beside it (boxes,
/// one maybe ticked: `ロロレ`) is no trace.
library;

import 'package:shiori_core/src/extract/extracted_word.dart';
import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/extract/script_runs.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';
import 'package:shiori_core/src/ports/lexicon.dart';

/// How far left of the kana, in its line heights, a trace may be.
const double traceReach = 15;

/// Words of [words] read back where a trace allows it, and the trace
/// fragments of the words read back (nothing is left of them for the tray).
/// [used] are the fragments something took (readings, meanings, sentences,
/// headwords).
Future<({List<ExtractedWord> words, Set<int> traces})> readBackHeadwords(
  List<ExtractedWord> words, {
  required List<Fragment> fragments,
  required Set<int> used,
  required KoreanReverseGlossary glossary,
  required Lexicon lexicon,
}) async {
  final tracesOf = <int, List<Fragment>>{};
  final kanaOf = <int, Fragment>{};
  for (final (i, w) in words.indexed) {
    final kana = _readBackCandidate(w, fragments);
    if (kana == null) continue;
    final traces = _traces(kana, fragments, used);
    if (traces.isEmpty) continue;
    kanaOf[i] = kana;
    tracesOf[i] = traces;
  }
  final none = (words: words, traces: const <int>{});
  if (kanaOf.isEmpty) return none;
  final List<GlossedSpelling> spellings;
  try {
    spellings = await glossary.reverseLookup({
      for (final k in kanaOf.values) hiragana(k.text),
    });
  } on Exception {
    // A damaged glossary: the kana stay as read.
    return none;
  }
  // The glossary's keys fold katakana to hiragana: the dictionary gives the
  // spelling as printed (`がす代` → `ガス代`), else only kanji-only keys stand.
  // It is asked with the kana as printed (it keeps mixed kana as they are,
  // `ガスだい`) and folded to hiragana.
  final byReading = await lexicon.lookup({
    for (final k in kanaOf.values) ...{k.text, hiragana(k.text)},
  });
  final named = <int, List<String>>{
    for (final MapEntry(key: i, value: kana) in kanaOf.entries)
      i: _spelled(_spellingsNaming(spellings, kana.text, words[i].meaning!), [
        ...?byReading[kana.text],
        ...?byReading[hiragana(kana.text)],
      ]),
  };
  final entries = await lexicon.lookup({for (final s in named.values) ...s});
  final chosen = {
    for (final MapEntry(key: i, value: s) in named.entries)
      i: _preferCommon(s, kanaOf[i]!.text, entries),
  };
  return (
    words: [
      for (final (i, w) in words.indexed)
        switch (chosen[i]) {
          null || [] => w,
          [final written] => _restored(
            w,
            kanaOf[i]!,
            written,
            entries[written],
          ),
          final several => w.copyWith(headwordCandidates: several),
        },
    ],
    traces: {
      for (final MapEntry(key: i, value: s) in chosen.entries)
        if (s.length == 1)
          for (final f in tracesOf[i]!) f.id,
    },
  );
}

/// [keys] as the dictionary spells them: the kanji form of an entry read
/// so whose kana folded to hiragana is the key; a key the dictionary does
/// not have stays only when it has no kana to fold.
List<String> _spelled(List<String> keys, List<LexiconEntry> entries) {
  final out = <String>[];
  for (final key in keys) {
    final form = [
      for (final e in entries)
        for (final k in e.kanjiForms)
          if (hiragana(k) == key) k,
    ].firstOrNull;
    final spelled = form ?? (key.runes.any(isKana) ? null : key);
    if (spelled != null && !out.contains(spelled)) out.add(spelled);
  }
  return out;
}

/// Of several spellings, the one the dictionary marks common for [kana]
/// when it is the only common one (箱 rather than 函 for はこ); else all.
List<String> _preferCommon(
  List<String> spellings,
  String kana,
  Map<String, List<LexiconEntry>> entries,
) {
  if (spellings.length < 2) return spellings;
  final common = [
    for (final s in spellings)
      if (entries[s]?.any(
            (e) =>
                e.isCommon && e.readings.map(hiragana).contains(hiragana(kana)),
          ) ??
          false)
        s,
  ];
  return common.length == 1 ? common : spellings;
}

/// The kana fragment of a kana word whose meaning the photo gave.
Fragment? _readBackCandidate(ExtractedWord w, List<Fragment> fragments) {
  final id = w.headwordFragmentId;
  if (w.origin != WordOrigin.wordList ||
      w.headwordSource != FieldSource.photo ||
      w.meaning == null ||
      w.meaningSource != FieldSource.photo ||
      w.readings.isNotEmpty ||
      id == null ||
      id < 0 ||
      id >= fragments.length) {
    return null;
  }
  final f = fragments[id];
  return f.kind == FragmentKind.kana && f.text == w.headword ? f : null;
}

/// What OCR read where the headword is, left of [kana] on its row, that
/// came to nothing.
List<Fragment> _traces(Fragment kana, List<Fragment> fragments, Set<int> used) {
  bool sameRow(Fragment f) =>
      (f.cy - kana.cy).abs() <
      (f.height > kana.height ? f.height : kana.height);
  bool leftOf(Fragment f) =>
      f.right <= kana.x + 0.5 * kana.height &&
      kana.x - f.right <= traceReach * kana.height;
  return [
    for (final f in fragments)
      if (f.id != kana.id &&
          !used.contains(f.id) &&
          sameRow(f) &&
          leftOf(f) &&
          _isTrace(f) &&
          !_checkboxMarks(f, fragments))
        f,
  ];
}

/// Glyphs OCR reads for an empty checkbox.
final Set<int> _boxGlyphs = '□■☐☑☒口ロコ'.runes.toSet();

/// Glyphs OCR reads for the tick in a checked box (`ロロレ`).
final Set<int> _tickGlyphs = 'レﾚ✓✔√VvノL'.runes.toSet();

/// Rows of boxes that line up with [f] before it is a checkbox column.
const int minColumnBoxes = 2;

/// [f] is what OCR read of a checkbox column, not of a headword: box glyphs
/// (also one taken off its front) with a tick at most, whose left edge is
/// within a glyph of at least [minColumnBoxes] other Japanese fragments of
/// box glyphs only.
bool _checkboxMarks(Fragment f, List<Fragment> fragments) {
  if (f.text.isEmpty) return false;
  final prefix = f.droppedPrefix ?? '';
  final glyphs = (prefix + f.text).replaceAll(_space, '').runes.toList();
  final boxes = glyphs.where(_boxGlyphs.contains).length;
  if (boxes == 0 ||
      glyphs.length - boxes > 1 ||
      glyphs.any((c) => !_boxGlyphs.contains(c) && !_tickGlyphs.contains(c))) {
    return false;
  }
  final glyph = f.width / f.text.length;
  final left = f.x - glyph * prefix.length;
  bool boxesOnly(Fragment o) {
    final t = o.text.replaceAll(_space, '');
    return t.isNotEmpty && t.runes.every(_boxGlyphs.contains);
  }

  return fragments
          .where(
            (o) =>
                o.id != f.id &&
                o.pass == OcrPass.japanese &&
                (o.x - left).abs() <= glyph &&
                boxesOnly(o),
          )
          .length >=
      minColumnBoxes;
}

final RegExp _space = RegExp(r'\s');

/// Something on [kana]'s row to its left says OCR lost a headword there:
/// a trace of a failed read (as for reading back), or marks (Latin
/// letters, box glyphs) with an empty headword cell, at least
/// [emptyCellLines] of the kana's line heights, between them and the kana.
/// A kana headword printed beside its checkbox has its marks right next to
/// it; one with something read between (a number column) is not lost
/// either. [used] are the fragments the page's words took.
bool hasHeadwordTrace(Fragment kana, List<Fragment> fragments, Set<int> used) {
  if (_traces(kana, fragments, used).isNotEmpty) return true;
  bool onRow(Fragment f) =>
      (f.cy - kana.cy).abs() <
      (f.height > kana.height ? f.height : kana.height);
  bool emptyBetween(Fragment marks) => !fragments.any(
    (g) =>
        g.id != marks.id &&
        g.id != kana.id &&
        g.kind != FragmentKind.noise &&
        onRow(g) &&
        g.x >= marks.right &&
        g.right <= kana.x + 0.5 * kana.height,
  );
  return fragments.any(
    (f) =>
        f.kind == FragmentKind.noise &&
        f.pass == OcrPass.japanese &&
        _marks.hasMatch(f.text.trim()) &&
        onRow(f) &&
        kana.x - f.right >= emptyCellLines * kana.height &&
        kana.x - f.right <= traceReach * kana.height &&
        emptyBetween(f),
  );
}

/// A headword cell this many of the kana's line heights wide is empty.
const double emptyCellLines = 3;

final RegExp _marks = RegExp('^[A-Za-z□■☐☑☒口ロコ]+\$');

bool _isTrace(Fragment f) => switch (f.kind) {
  FragmentKind.kanjiWord || FragmentKind.kana => f.pass == OcrPass.japanese,
  FragmentKind.hangul =>
    f.pass == OcrPass.korean && f.text.runes.where(isHangul).length <= 1,
  FragmentKind.noise => f.text.trim() == '口' || f.text.trim() == 'ロ',
  _ => false,
};

/// Kanji spellings read [kana] whose Korean words name a part of
/// [meaning], in the glossary's order.
List<String> _spellingsNaming(
  List<GlossedSpelling> spellings,
  String kana,
  String meaning,
) {
  final parts = {
    for (final p in meaning.split(RegExp(r'[,，、/·;]+'))) ?_bare(p),
  };
  final reading = hiragana(kana);
  final out = <String>[];
  for (final s in spellings) {
    if (hiragana(s.reading) != reading || !s.written.runes.any(isKanji)) {
      continue;
    }
    if (!s.words.any((w) => parts.contains(_bare(w)))) continue;
    if (!out.contains(s.written)) out.add(s.written);
  }
  return out;
}

String? _bare(String s) {
  final b = s.replaceAll(RegExp(r'\([^)]*\)|[^가-힣]'), '');
  return b.isEmpty ? null : b;
}

ExtractedWord _restored(
  ExtractedWord w,
  Fragment kana,
  String written,
  List<LexiconEntry>? entries,
) {
  final entry = entries?.where(
    (e) => e.readings.map(hiragana).contains(hiragana(kana.text)),
  );
  return ExtractedWord(
    headword: written,
    origin: WordOrigin.wordList,
    readings: [kana.text],
    meaning: w.meaning,
    meaningNotes: w.meaningNotes,
    partsOfSpeech: entry == null || entry.isEmpty
        ? const []
        : entry.first.partsOfSpeech,
    headwordSource: FieldSource.dictionary,
    readingSource: FieldSource.photo,
    meaningSource: w.meaningSource,
    readingLink: PairLink(
      confidence: PairConfidence.medium,
      signals: const {PairSignal.dictionaryPair},
      fragmentId: kana.id,
    ),
    meaningLink: w.meaningLink,
    readQuality: w.readQuality,
    headwordFragmentId: w.headwordFragmentId,
    headwordNote: '${kana.text} → $written (사전 역조회)',
    meaningCandidates: w.meaningCandidates,
    printedPos: w.printedPos,
  );
}

/// Katakana folded to hiragana (ー and other marks stay).
String hiragana(String s) => String.fromCharCodes(
  s.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r),
);
