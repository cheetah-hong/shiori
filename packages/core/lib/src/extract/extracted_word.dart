/// What the word extractor returns: words with where each field came from,
/// how sure the pairing is, and the fragments nothing paired with.
library;

import 'package:shiori_core/src/extract/fragment.dart';
import 'package:shiori_core/src/extract/latin_debris.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/evidence.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';

export 'package:shiori_core/src/models/evidence.dart'
    show FieldSource, PairConfidence, WordOrigin;

/// Evidence that two fragments belong together.
enum PairSignal {
  /// The reading is printed in brackets right after the headword. The page
  /// itself states the pair, so this counts as two signals.
  inlineNotation,

  /// The dictionary has the headword with this reading.
  dictionaryPair,

  /// The Korean text spells the headword's kanji in Korean readings
  /// (図書館 → 도서관).
  hanjaReading,

  /// A Korean gloss lookup lists the Korean text for the headword.
  koreanGloss,

  /// Placement: same row, right below, furigana above. Never counts as
  /// content.
  position,
}

/// One pairing of a headword with its reading or its meaning.
final class PairLink {
  const PairLink({
    required this.confidence,
    required this.signals,
    this.fragmentId,
    this.note,
  });

  final PairConfidence confidence;
  final Set<PairSignal> signals;

  /// The fragment the value came from; null when it came from the dictionary.
  final int? fragmentId;

  /// Why the confidence is lower than the signals suggest (for example the
  /// dictionary does not have the printed reading).
  final String? note;

  @override
  String toString() =>
      '${confidence.name}{${signals.map((s) => s.name).join(',')}}'
      '${fragmentId == null ? '' : '#$fragmentId'}${note == null ? '' : ' ($note)'}';
}

/// OCR side of a word's trust, kept apart from the pairing.
final class ReadQuality {
  const ReadQuality({required this.ocrConfidence, this.corrected = false});

  /// Lowest OCR confidence of the fragments the word uses.
  final double ocrConfidence;

  /// Glyphs were removed or changed from what OCR returned.
  final bool corrected;

  @override
  String toString() =>
      'read ${ocrConfidence.toStringAsFixed(2)}${corrected ? ' corrected' : ''}';
}

/// Example sentence a word came from, with its translation when one was
/// printed beside it.
final class WordExample {
  const WordExample({required this.ja, this.ko});

  final String ja;
  final String? ko;

  @override
  bool operator ==(Object other) =>
      other is WordExample && other.ja == ja && other.ko == ko;

  @override
  int get hashCode => Object.hash(ja, ko);

  @override
  String toString() => 'WordExample($ja / $ko)';
}

/// How a meaning filled from the dictionary is noted.
const String dictionaryMeaningNote = '사전 뜻';

final class ExtractedWord {
  const ExtractedWord({
    required this.headword,
    required this.origin,
    this.readings = const [],
    this.meaning,
    this.meaningNotes = const [],
    this.partsOfSpeech = const [],
    this.headwordSource = FieldSource.photo,
    this.readingSource,
    this.meaningSource,
    this.readingLink,
    this.meaningLink,
    this.readQuality = const ReadQuality(ocrConfidence: 1.0),
    this.example,
    this.headwordFragmentId,
    this.headwordNote,
    this.meaningCandidates = const [],
    this.headwordCandidates = const [],
    this.printedPos,
    this.usagePos,
    this.negated = false,
    this.meaningRepair,
    this.meaningGlossary,
  });

  /// Dictionary form: kanji (with okurigana) or, for kana words, the kana.
  final String headword;

  /// Readings in kana; empty for kana words.
  final List<String> readings;

  /// Korean meaning as printed, without the notes; null when none paired.
  final String? meaning;
  final List<String> meaningNotes;

  /// JMdict POS codes from the dictionary (empty without one).
  final List<String> partsOfSpeech;

  final FieldSource headwordSource;
  final FieldSource? readingSource;
  final FieldSource? meaningSource;

  /// Evidence for the reading (null when there is no reading or the word is kana).
  final PairLink? readingLink;

  /// Evidence for the meaning (null when no meaning paired).
  final PairLink? meaningLink;

  final ReadQuality readQuality;
  final WordOrigin origin;
  final WordExample? example;

  /// The fragment the headword was read from (sentence words: the sentence).
  final int? headwordFragmentId;

  /// Why the headword differs from what OCR read (`人ロ → 人口 (글자 보정+사전)`).
  final String? headwordNote;

  /// Other meanings to offer: the glossary's other senses.
  final List<String> meaningCandidates;

  /// The glossary a meaning filled from the dictionary came from; null for
  /// a meaning from the page.
  final GlossarySource? meaningGlossary;

  /// How a meaning from the dictionary is noted: `사전 뜻`, with the
  /// glossary's name when it is not the Basic Korean Dictionary
  /// (`사전 뜻: 위키낱말사전`).
  String get _dictionaryNote => switch (meaningGlossary) {
    null || GlossarySource.krdict => dictionaryMeaningNote,
    final GlossarySource other => '$dictionaryMeaningNote: ${other.label}',
  };

  /// Headwords to offer when OCR did not read the printed one and the
  /// glossary read backwards gives more than one spelling for its kana.
  final List<String> headwordCandidates;

  /// The POS badge printed before the meaning (`동 걷다` → verb); null
  /// without one. It outranks [partsOfSpeech] when the glossary is asked
  /// for the word's senses.
  final PartOfSpeech? printedPos;

  /// The class a sentence word's sentence uses it as (`静かだ`: な-adjective)
  /// when the dictionary gives it several; null otherwise. Next to
  /// [printedPos] when the glossary is asked for the word's senses.
  final PartOfSpeech? usagePos;

  /// A sentence word with a negative after it in its clause (別に行かない):
  /// its meaning takes the sense used with a negative (meaning_senses.dart).
  final bool negated;

  /// What became of Latin debris in the photo's meaning (latin_debris.dart);
  /// null when the meaning had none.
  final MeaningRepairKind? meaningRepair;

  /// The weakest pairing of the word; [PairConfidence.low] when nothing is
  /// paired with the headword at all.
  PairConfidence get pairConfidence {
    final links = [?readingLink, ?meaningLink];
    if (links.isEmpty) return PairConfidence.low;
    return links
        .map((l) => l.confidence)
        .reduce((a, b) => a.index <= b.index ? a : b);
  }

  ExtractedWord copyWith({
    List<String>? readings,
    Object? meaning = _unset,
    List<String>? meaningNotes,
    List<String>? partsOfSpeech,
    Object? readingSource = _unset,
    Object? meaningSource = _unset,
    Object? readingLink = _unset,
    Object? meaningLink = _unset,
    ReadQuality? readQuality,
    WordOrigin? origin,
    Object? example = _unset,
    List<String>? meaningCandidates,
    List<String>? headwordCandidates,
    Object? meaningRepair = _unset,
    Object? meaningGlossary = _unset,
  }) => ExtractedWord(
    headword: headword,
    origin: origin ?? this.origin,
    readings: List.unmodifiable(readings ?? this.readings),
    meaning: identical(meaning, _unset) ? this.meaning : meaning as String?,
    meaningNotes: List.unmodifiable(meaningNotes ?? this.meaningNotes),
    partsOfSpeech: List.unmodifiable(partsOfSpeech ?? this.partsOfSpeech),
    headwordSource: headwordSource,
    readingSource: identical(readingSource, _unset)
        ? this.readingSource
        : readingSource as FieldSource?,
    meaningSource: identical(meaningSource, _unset)
        ? this.meaningSource
        : meaningSource as FieldSource?,
    readingLink: identical(readingLink, _unset)
        ? this.readingLink
        : readingLink as PairLink?,
    meaningLink: identical(meaningLink, _unset)
        ? this.meaningLink
        : meaningLink as PairLink?,
    readQuality: readQuality ?? this.readQuality,
    example: identical(example, _unset)
        ? this.example
        : example as WordExample?,
    headwordFragmentId: headwordFragmentId,
    headwordNote: headwordNote,
    meaningCandidates: List.unmodifiable(
      meaningCandidates ?? this.meaningCandidates,
    ),
    headwordCandidates: List.unmodifiable(
      headwordCandidates ?? this.headwordCandidates,
    ),
    printedPos: printedPos,
    usagePos: usagePos,
    negated: negated,
    meaningRepair: identical(meaningRepair, _unset)
        ? this.meaningRepair
        : meaningRepair as MeaningRepairKind?,
    meaningGlossary: identical(meaningGlossary, _unset)
        ? this.meaningGlossary
        : meaningGlossary as GlossarySource?,
  );

  /// The review-draft entry the capture screens use. Fields the photo did
  /// not give are flagged
  /// missing, and a meaning paired below [PairConfidence.high] is flagged for
  /// review. [fragments] (the extraction's) give the photo boxes behind each
  /// cell.
  CapturedEntry toCapturedEntry({List<Fragment> fragments = const []}) {
    List<PhotoBox> boxes(Iterable<int?> ids) => [
      for (final id in ids)
        if (id != null && id >= 0 && id < fragments.length)
          PhotoBox(
            x: fragments[id].x,
            y: fragments[id].y,
            width: fragments[id].width,
            height: fragments[id].height,
          ),
    ];
    final fromDictionary = meaningSource == FieldSource.dictionary;
    return CapturedEntry(
      headword: headword,
      readings: readings,
      pos: partOfSpeechOf(partsOfSpeech),
      meaning: meaning ?? '',
      example: switch (example) {
        WordExample(:final ja, :final ko) => Example(ja: ja, ko: ko ?? ''),
        null => null,
      },
      issues: [
        if (headwordNote != null)
          EntryIssue.corrected(EntryField.headword, note: headwordNote),
        if (headwordNote == null && headwordCandidates.isNotEmpty)
          EntryIssue.suspect(
            EntryField.headword,
            note: '사전 역조회 후보 ${headwordCandidates.length}',
          ),
        if (meaning == null) const EntryIssue.missing(EntryField.meaning),
        if (meaning != null && fromDictionary)
          EntryIssue.inferred(EntryField.meaning, note: _dictionaryNote),
        if (meaningRepair
            case MeaningRepairKind.trimmed || MeaningRepairKind.senseDropped)
          const EntryIssue.corrected(
            EntryField.meaning,
            note: latinDebrisRemovedNote,
          ),
        if (meaningRepair == MeaningRepairKind.flagged)
          const EntryIssue.suspect(
            EntryField.meaning,
            note: latinDebrisUnsureNote,
          ),
        if (meaning != null &&
            !fromDictionary &&
            meaningLink?.confidence != PairConfidence.high)
          EntryIssue.suspect(
            EntryField.meaning,
            note: 'pair ${meaningLink?.confidence.name ?? 'none'}',
          ),
        if (readingSource == FieldSource.dictionary)
          const EntryIssue.inferred(EntryField.readings, note: 'dictionary'),
      ],
      ocrHeadword: headword,
      headwordCandidates: headwordCandidates,
      evidence: EntryEvidence(
        origin: origin,
        fields: {
          EntryField.headword: FieldEvidence(
            source: headwordSource,
            boxes: boxes([headwordFragmentId]),
            candidates: headwordCandidates,
            note:
                headwordNote ??
                (headwordCandidates.isEmpty
                    ? null
                    : '사전 역조회 후보 ${headwordCandidates.length}'),
          ),
          if (readings.isNotEmpty)
            EntryField.readings: FieldEvidence(
              source: readingSource ?? FieldSource.photo,
              confidence: readingLink?.confidence,
              boxes: readingSource == FieldSource.photo
                  ? boxes([readingLink?.fragmentId])
                  : const [],
              note: readingLink?.note,
            ),
          if (meaning != null)
            EntryField.meaning: FieldEvidence(
              source: meaningSource ?? FieldSource.photo,
              confidence: meaningLink?.confidence,
              boxes: meaningSource == FieldSource.photo
                  ? boxes([meaningLink?.fragmentId])
                  : const [],
              candidates: meaningCandidates,
              note: fromDictionary ? _dictionaryNote : meaningLink?.note,
            ),
          if (example != null)
            EntryField.example: FieldEvidence(
              source: FieldSource.photo,
              boxes: boxes([headwordFragmentId]),
            ),
        },
      ),
    );
  }

  @override
  String toString() =>
      'ExtractedWord($headword|${readings.join('/')}|$meaning '
      '${origin.name} reading=$readingLink meaning=$meaningLink)';
}

/// The textbook badge for JMdict POS codes, first content class wins.
PartOfSpeech? partOfSpeechOf(List<String> codes) {
  for (final c in codes) {
    final pos = switch (c) {
      'adj-i' || 'adj-ix' => PartOfSpeech.iAdjective,
      'adj-na' => PartOfSpeech.naAdjective,
      'adv' || 'adv-to' => PartOfSpeech.adverb,
      'conj' => PartOfSpeech.conjunction,
      'int' => PartOfSpeech.interjection,
      'adj-pn' => PartOfSpeech.prenominal,
      'prt' => PartOfSpeech.particle,
      'n' || 'n-suf' || 'n-pref' || 'pn' || 'num' || 'ctr' => PartOfSpeech.noun,
      _ when c.startsWith('v') && c != 'vs' && c != 'vt' && c != 'vi' =>
        PartOfSpeech.verb,
      _ => null,
    };
    if (pos != null) return pos;
  }
  return null;
}

/// Everything one page gave.
final class ExtractionResult {
  const ExtractionResult({
    required this.words,
    required this.unpaired,
    required this.fragments,
    this.elapsed = Duration.zero,
    this.skippedKnown = const [],
  });

  final List<ExtractedWord> words;

  /// Content fragments nothing used: a Korean meaning with no headword, a
  /// kanji word that is neither a word nor a reading, ... Kept for the
  /// learner to place by hand.
  final List<Fragment> unpaired;

  /// Every fragment collected from the page, noise included.
  final List<Fragment> fragments;

  /// Extraction time (OCR not included).
  final Duration elapsed;

  /// Headwords left out because the learner already has them, each once.
  final List<String> skippedKnown;
}

const Object _unset = Object();
