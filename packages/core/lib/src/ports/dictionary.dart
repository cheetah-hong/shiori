/// Block slot: a Japanese dictionary used to suggest or check words.
///
/// First block: [EmptyDictionary]. Next: JMdict in SQLite (CC BY-SA 4.0).
abstract interface class Dictionary {
  Future<List<DictionaryEntry>> byReading(String reading, {int limit = 5});

  Future<List<DictionaryEntry>> byHeadword(String headword, {int limit = 5});
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

/// Knows no words. Keeps the dictionary slot filled until JMdict lands.
final class EmptyDictionary implements Dictionary {
  const EmptyDictionary();

  @override
  Future<List<DictionaryEntry>> byReading(
    String reading, {
    int limit = 5,
  }) async => const [];

  @override
  Future<List<DictionaryEntry>> byHeadword(
    String headword, {
    int limit = 5,
  }) async => const [];
}
