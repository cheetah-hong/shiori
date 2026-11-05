/// Block slot: dictionary facts the word extractor needs (forms, readings,
/// parts of speech, frequency), many forms per call.
///
/// Separate from `Dictionary` (which serves the textbook templates) so either
/// can grow without touching the other. The app plugs in JMdict through the
/// `jmdict_block` adapter; core knows no dictionary data.
library;

/// JMdict priority tags as bits, the layout of the `pri` columns:
/// news1 1, news2 2, ichi1 4, ichi2 8, spec1 16, spec2 32, gai1 64, gai2 128.
const int lexiconCommonMask = 1 | 4 | 16 | 32 | 64;

abstract interface class Lexicon {
  /// Entries written as each of [forms]: a kanji form, or a kana reading
  /// (hiragana and katakana spellings both match). Forms with no entry are
  /// left out of the map. One call for many forms, so a block can answer
  /// them in a single query.
  Future<Map<String, List<LexiconEntry>>> lookup(Iterable<String> forms);
}

/// One dictionary entry as seen from the form that was looked up.
final class LexiconEntry {
  const LexiconEntry({
    required this.id,
    required this.form,
    required this.readings,
    this.kanjiForms = const [],
    this.partsOfSpeech = const [],
    this.priority = 0,
    this.nf,
    this.usuallyKana = false,
  });

  /// JMdict `ent_seq` (or any id unique within the block).
  final int id;

  /// The form that was looked up, as the entry writes it.
  final String form;

  /// Readings that go with [form] (for a kana form: the form itself).
  final List<String> readings;

  /// Every kanji form of the entry; empty for words written only in kana.
  final List<String> kanjiForms;

  /// JMdict POS codes of the entry: `n`, `v1`, `v5k`, `adj-i`, `prt`, ...
  final List<String> partsOfSpeech;

  /// Priority bits of [form] ([lexiconCommonMask] for the common ones).
  final int priority;

  /// nfXX frequency band of [form]: 1 is the 500 most frequent words.
  final int? nf;

  /// The entry is usually written in kana (JMdict `uk`).
  final bool usuallyKana;

  /// [form] is a reading of the entry, not one of its kanji forms.
  bool get isKanaForm => !kanjiForms.contains(form);

  bool get isCommon => priority & lexiconCommonMask != 0;

  /// The entry has no kanji, or is usually written in kana: a kana spelling
  /// of it is a normal way to write the word.
  bool get writtenInKana => kanjiForms.isEmpty || usuallyKana;

  @override
  String toString() =>
      '$form【${readings.join('/')}】#$id ${partsOfSpeech.join(' ')}';
}

/// Knows no words: keeps the slot filled when no dictionary is plugged in.
final class EmptyLexicon implements Lexicon {
  const EmptyLexicon();

  @override
  Future<Map<String, List<LexiconEntry>>> lookup(
    Iterable<String> forms,
  ) async => const {};
}

/// A few words held in memory (tests and the synthetic evaluation set).
final class InMemoryLexicon implements Lexicon {
  InMemoryLexicon(Iterable<LexiconWord> words) : _byForm = _index(words);

  /// `{"entries": [{"id", "kanji": [...], "readings": [...], "pos": [...],
  /// "pri", "nf", "uk"}]}`. Throws [FormatException] on a malformed entry.
  factory InMemoryLexicon.fromJson(Map<String, Object?> json) {
    final raw = json['entries'];
    if (raw is! List) {
      throw const FormatException('lexicon JSON needs an "entries" list');
    }
    return InMemoryLexicon([
      for (final e in raw)
        if (e is Map)
          LexiconWord.fromJson(e.cast<String, Object?>())
        else
          throw FormatException('lexicon entry must be an object', e),
    ]);
  }

  final Map<String, List<LexiconEntry>> _byForm;

  @override
  Future<Map<String, List<LexiconEntry>>> lookup(
    Iterable<String> forms,
  ) async => {
    for (final f in forms) f: ?(_byForm[f] ?? _byForm[_otherScript(f)]),
  };

  static Map<String, List<LexiconEntry>> _index(Iterable<LexiconWord> words) {
    final out = <String, List<LexiconEntry>>{};
    for (final w in words) {
      for (final k in w.kanji) {
        (out[k] ??= []).add(
          LexiconEntry(
            id: w.id,
            form: k,
            readings: w.readings,
            kanjiForms: w.kanji,
            partsOfSpeech: w.pos,
            priority: w.priority,
            nf: w.nf,
            usuallyKana: w.usuallyKana,
          ),
        );
      }
      for (final r in w.readings) {
        (out[r] ??= []).add(
          LexiconEntry(
            id: w.id,
            form: r,
            readings: [r],
            kanjiForms: w.kanji,
            partsOfSpeech: w.pos,
            priority: w.priority,
            nf: w.nf,
            usuallyKana: w.usuallyKana,
          ),
        );
      }
    }
    return {
      for (final MapEntry(:key, :value) in out.entries)
        key: List.unmodifiable(value),
    };
  }
}

/// A word for [InMemoryLexicon]: its kanji forms and readings.
final class LexiconWord {
  const LexiconWord({
    required this.id,
    this.kanji = const [],
    required this.readings,
    this.pos = const [],
    this.priority = 0,
    this.nf,
    this.usuallyKana = false,
  });

  factory LexiconWord.fromJson(Map<String, Object?> json) => LexiconWord(
    id: _int(json, 'id'),
    kanji: _strings(json, 'kanji'),
    readings: _strings(json, 'readings'),
    pos: _strings(json, 'pos'),
    priority: json['pri'] == null ? 0 : _int(json, 'pri'),
    nf: json['nf'] == null ? null : _int(json, 'nf'),
    usuallyKana: json['uk'] == true,
  );

  final int id;
  final List<String> kanji;
  final List<String> readings;
  final List<String> pos;
  final int priority;
  final int? nf;
  final bool usuallyKana;
}

int _int(Map<String, Object?> json, String key) => switch (json[key]) {
  final int v => v,
  final v => throw FormatException('lexicon "$key" must be an integer', v),
};

List<String> _strings(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => const [],
      final List<Object?> v when v.every((s) => s is String) =>
        List.unmodifiable(v.cast<String>()),
      final v => throw FormatException(
        'lexicon "$key" must be a string list',
        v,
      ),
    };

/// ァ..ヶ ↔ ぁ..ゖ for a kana-only form; the form itself otherwise.
String _otherScript(String s) {
  final runes = s.runes.toList();
  if (runes.every((r) => r >= 0x3041 && r <= 0x3096 || r == 0x30FC)) {
    return String.fromCharCodes(runes.map((r) => r == 0x30FC ? r : r + 0x60));
  }
  if (runes.every((r) => r >= 0x30A1 && r <= 0x30F6 || r == 0x30FC)) {
    return String.fromCharCodes(runes.map((r) => r == 0x30FC ? r : r - 0x60));
  }
  return s;
}
