import 'package:shiori_core/src/models/part_of_speech.dart';

/// Block slot: a Japanese dictionary used to suggest or check words.
///
/// First block: [EmptyDictionary]. The app plugs in JMdict (SQLite,
/// CC BY-SA 4.0) through an adapter package; core knows neither.
abstract interface class Dictionary {
  /// Words printed with [reading], best first. [pos] (the textbook's badge)
  /// moves words of that class forward; it never filters.
  Future<List<DictionaryEntry>> byReading(
    String reading, {
    int limit = 5,
    PartOfSpeech? pos,
  });

  Future<List<DictionaryEntry>> byHeadword(String headword, {int limit = 5});

  /// Whether the dictionary has [headword] with every reading in [readings]
  /// (empty: a kana word printed without a reading).
  Future<PairStatus> checkPair(String headword, List<String> readings);

  /// Dictionary headwords [ocrHeadword] could be through look-alike glyphs
  /// (`ー日` → `一日`), best first; empty when none.
  Future<List<String>> fixHeadword(
    String ocrHeadword,
    String reading, {
    PartOfSpeech? pos,
    int limit = 3,
  });
}

/// Answer of [Dictionary.checkPair].
enum PairStatus {
  /// The dictionary has the pair (allowing kana script, okurigana and
  /// `〜する` differences).
  known,

  /// Found only as two dictionary words in a row: a weak match.
  compoundOnly,

  /// Not in the dictionary. The learner should check the word.
  notFound,

  /// No dictionary to ask ([EmptyDictionary]).
  unavailable,
}

final class DictionaryEntry {
  const DictionaryEntry({
    required this.headword,
    required this.readings,
    this.glosses = const [],
  });

  final String headword;
  final List<String> readings;
  final List<String> glosses;
}

/// Knows no words. Keeps the dictionary slot filled when no dictionary data
/// ships with the app (or it could not be opened).
final class EmptyDictionary implements Dictionary {
  const EmptyDictionary();

  @override
  Future<List<DictionaryEntry>> byReading(
    String reading, {
    int limit = 5,
    PartOfSpeech? pos,
  }) async => const [];

  @override
  Future<List<DictionaryEntry>> byHeadword(
    String headword, {
    int limit = 5,
  }) async => const [];

  @override
  Future<PairStatus> checkPair(String headword, List<String> readings) async =>
      PairStatus.unavailable;

  @override
  Future<List<String>> fixHeadword(
    String ocrHeadword,
    String reading, {
    PartOfSpeech? pos,
    int limit = 3,
  }) async => const [];
}
