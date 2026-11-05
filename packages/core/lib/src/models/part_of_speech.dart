/// Part-of-speech badges printed in the word lists (`[명]`, `[동]`, ...).
enum PartOfSpeech {
  noun('명', '명사'),
  verb('동', '동사'),
  adjective('형', '형용사'),
  iAdjective('い형', 'い형용사'),
  naAdjective('な형', 'な형용사'),
  adverb('부', '부사'),
  conjunction('접', '접속사'),
  interjection('감', '감탄사'),
  prenominal('연', '연체사'),
  particle('조', '조사');

  const PartOfSpeech(this.badge, this.label);

  /// Short badge as printed in the textbook, for example `명`.
  final String badge;

  /// Full Korean name, for example `명사`.
  final String label;

  static PartOfSpeech? fromBadge(String? badge) {
    for (final pos in values) {
      if (pos.badge == badge) return pos;
    }
    return null;
  }
}
