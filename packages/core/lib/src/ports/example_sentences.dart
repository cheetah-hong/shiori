/// Block slot: example sentences for words whose page printed none, by
/// dictionary entry (JMdict `ent_seq`, as `LexiconEntry.id`).
///
/// The app plugs in Tatoeba through `example_block`; core knows no sentence
/// data.
library;

/// One sentence filed under a dictionary entry.
final class StoredExample {
  const StoredExample({
    required this.entryId,
    required this.reading,
    required this.sentenceId,
    required this.ja,
    this.ko,
    this.en,
    this.surface,
  });

  /// The entry the sentence uses.
  final int entryId;

  /// The entry's reading the sentence uses; '' when it may be any.
  final String reading;

  /// The sentence's number in its source (Tatoeba).
  final int sentenceId;

  final String ja;

  /// A Korean translation of this very sentence, when there is one.
  final String? ko;

  /// An English translation, only when there is no Korean one.
  final String? en;

  /// How the word is written in the sentence (`汚して` for 汚す), when known.
  final String? surface;
}

abstract interface class ExampleSentences {
  /// The sentences filed under [entryIds], in the order of the ids asked.
  Future<List<StoredExample>> lookup(Iterable<int> entryIds);
}

/// No sentence data (a build without the example asset, tests).
final class EmptyExampleSentences implements ExampleSentences {
  const EmptyExampleSentences();

  @override
  Future<List<StoredExample>> lookup(Iterable<int> entryIds) async => const [];
}
