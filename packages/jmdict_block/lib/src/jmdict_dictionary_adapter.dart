import 'package:dict_jmdict/dict_jmdict.dart' as jm;
import 'package:shiori_core/shiori_core.dart';

/// The core `Dictionary` port over a JMdict SQLite file (dict_jmdict).
///
/// dict_jmdict's calls are synchronous and fast (well under a millisecond on
/// the full dictionary); they are wrapped in futures for the port.
final class JmdictDictionaryAdapter implements Dictionary {
  JmdictDictionaryAdapter(this.jmdict);

  final jm.JmdictDictionary jmdict;

  /// Source, edition and licence notice of the data.
  jm.DictionaryInfo get info => jmdict.info;

  void close() => jmdict.close();

  /// Used when the headword was not read. A printed reading means the
  /// headword is not just that kana, so the bare reading is left out.
  @override
  Future<List<DictionaryEntry>> byReading(
    String reading, {
    int limit = 5,
    PartOfSpeech? pos,
  }) async => [
    for (final s in jmdict.suggestHeadword(
      '',
      reading,
      limit: limit,
      prefer: wordClassesFor(pos),
    ))
      DictionaryEntry(
        headword: s.headword,
        readings: [s.candidate.reading],
        glosses: s.candidate.glosses,
      ),
  ];

  @override
  Future<List<DictionaryEntry>> byHeadword(
    String headword, {
    int limit = 5,
  }) async => [
    for (final w in jmdict.lookupByHeadword(headword, limit: limit))
      DictionaryEntry(
        headword: w.headword,
        readings: w.readings,
        glosses: w.glosses,
      ),
  ];

  /// Every reading must pair with [headword]; any compound match makes the
  /// whole answer [PairStatus.compoundOnly].
  @override
  Future<PairStatus> checkPair(String headword, List<String> readings) async {
    final checks = readings.isEmpty
        ? [jmdict.checkPair(headword, null)]
        : [for (final r in readings) jmdict.checkPair(headword, r)];
    if (checks.any((c) => !c.isKnown)) return PairStatus.notFound;
    return checks.any((c) => c.match == jm.PairMatch.compound)
        ? PairStatus.compoundOnly
        : PairStatus.known;
  }

  @override
  Future<List<String>> fixHeadword(
    String ocrHeadword,
    String reading, {
    PartOfSpeech? pos,
    int limit = 3,
  }) async {
    if (ocrHeadword.trim().isEmpty) return const [];
    return [
      for (final s in jmdict.suggestHeadword(
        ocrHeadword,
        reading,
        limit: limit,
        prefer: wordClassesFor(pos),
      ))
        s.headword,
    ];
  }
}

/// Dictionary word classes for a textbook POS badge (ranking hints only).
Set<jm.WordClass> wordClassesFor(PartOfSpeech? pos) => switch (pos) {
  null => const {},
  PartOfSpeech.noun => const {jm.WordClass.noun},
  PartOfSpeech.verb => const {jm.WordClass.verb},
  PartOfSpeech.adjective => const {
    jm.WordClass.iAdjective,
    jm.WordClass.naAdjective,
  },
  PartOfSpeech.iAdjective => const {jm.WordClass.iAdjective},
  PartOfSpeech.naAdjective => const {jm.WordClass.naAdjective},
  PartOfSpeech.adverb => const {jm.WordClass.adverb},
  PartOfSpeech.conjunction => const {jm.WordClass.conjunction},
  PartOfSpeech.interjection => const {jm.WordClass.interjection},
  PartOfSpeech.prenominal => const {jm.WordClass.adnominal},
  PartOfSpeech.particle => const {jm.WordClass.particle},
};
