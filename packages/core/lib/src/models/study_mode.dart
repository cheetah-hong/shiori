/// How a card is studied. Each mode keeps its own record of a word (memory
/// level and next review), so knowing a word one way does not move it in
/// another.
///
/// Stored by name: renaming a value needs a schema migration.
enum StudyMode {
  /// See the Japanese word, recall its meaning (the first mode).
  meaning,

  /// See the meaning, recall the Japanese word and its reading.
  recall,

  /// Hear the word, pick its meaning out of four.
  listening,

  /// See the Japanese word, pick its meaning out of four.
  choice;

  /// The learner answers by picking a meaning out of four (객관식): the
  /// answer is checked, not judged by the learner.
  bool get isMultipleChoice => this == choice || this == listening;
}
