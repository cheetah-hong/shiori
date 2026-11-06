import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

/// Block slot: Korean meanings of a Japanese word, for cells the page did not
/// give (or OCR could not read).
///
/// First block: [EmptyKoreanGlossary]. The app plugs in the Basic Korean
/// Dictionary (한국어기초사전, CC BY-SA 2.0 KR) looked up backwards from its
/// Japanese equivalents, through an adapter package; core knows neither.
abstract interface class KoreanGlossary {
  /// Korean meanings of [headword], best first, at most [limit].
  ///
  /// [readings] are the word's readings in kana (empty for a kana word). A
  /// headword with kanji only matches the dictionary's spelling with one of
  /// these readings (しょくどう with 食堂 never gives 식도 of 食道).
  ///
  /// [pos] is the class the word is printed as (its badge on the page, else
  /// the dictionary's): senses of a Korean word of that class come first,
  /// after how the word matched. Nothing is left out for it; without such a
  /// sense the order is as without [pos].
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  });

  /// Where the meanings come from, for the 정보 screen. Empty without data.
  List<GlossarySourceInfo> get sources;
}

/// Block slot, optional: the glossary read backwards. A glossary that has it
/// implements this next to [KoreanGlossary]; one that does not is only read
/// forwards.
abstract interface class KoreanReverseGlossary {
  /// Japanese spellings the glossary has with one of [readings] (kana), each
  /// with the Korean words of one sense. The word extractor asks once a page
  /// for every kana whose headword OCR did not read, then keeps the
  /// spellings whose Korean words name the meaning printed beside it.
  Future<List<GlossedSpelling>> reverseLookup(Iterable<String> readings);
}

/// A Japanese spelling of a reading and the Korean words of one sense.
final class GlossedSpelling {
  const GlossedSpelling({
    required this.written,
    required this.reading,
    required this.words,
  });

  /// How the word is written (kanji, or the kana for a kana word).
  final String written;

  /// The reading in kana.
  final String reading;

  /// The sense's Korean words, closest first.
  final List<String> words;

  @override
  bool operator ==(Object other) =>
      other is GlossedSpelling &&
      other.written == written &&
      other.reading == reading &&
      listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(written, reading, Object.hashAll(words));

  @override
  String toString() =>
      'GlossedSpelling($written【$reading】 ${words.join(', ')})';
}

/// Dictionaries a [KoreanSense] can come from.
enum GlossarySource {
  /// 한국어기초사전 (National Institute of Korean Language), CC BY-SA 2.0 KR.
  krdict('한국어기초사전'),

  /// 한국어 위키낱말사전, CC BY-SA 4.0.
  wiktionary('위키낱말사전');

  const GlossarySource(this.label);

  /// Name shown to the learner (the review screen note, the 정보 screen).
  final String label;
}

/// Vocabulary level the source gives a Korean word.
enum GlossaryLevel { beginner, intermediate, advanced }

/// One meaning: the Korean words of one dictionary sense, closest first.
final class KoreanSense {
  const KoreanSense({
    required this.words,
    required this.source,
    this.level,
    this.senseNo,
  });

  /// Korean words, never empty. The first is the sense's own headword; the
  /// others are its synonyms that translate the same Japanese word.
  final List<String> words;
  final GlossarySource source;
  final GlossaryLevel? level;

  /// Number of the sense in the source entry (1 for its first sense).
  final int? senseNo;

  /// The words as a meaning cell, the way a textbook prints them (`다만, 단지`).
  String get text => words.join(', ');

  @override
  bool operator ==(Object other) =>
      other is KoreanSense &&
      other.source == source &&
      other.level == level &&
      other.senseNo == senseNo &&
      listEquals(other.words, words);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(words), source, level, senseNo);

  @override
  String toString() => 'KoreanSense($text, ${source.name} #$senseNo $level)';
}

/// Source and edition of the data behind a [KoreanGlossary].
final class GlossarySourceInfo {
  const GlossarySourceInfo({
    required this.source,
    required this.publisher,
    required this.license,
    required this.licenseUrl,
    required this.edition,
  });

  final GlossarySource source;

  /// Who publishes the data (`국립국어원`).
  final String publisher;

  /// Licence name (`CC BY-SA 2.0 KR`).
  final String license;
  final String licenseUrl;

  /// Date of the source data (`2026-10-19`).
  final String edition;

  /// The credit line the licence asks for.
  String get attribution =>
      '${source.label}, $publisher, $license, $edition판을 가공함';
}

/// Knows no meanings. Keeps the slot filled when no data ships with the app
/// (or it could not be opened).
final class EmptyKoreanGlossary implements KoreanGlossary {
  const EmptyKoreanGlossary();

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => const [];

  @override
  List<GlossarySourceInfo> get sources => const [];
}
