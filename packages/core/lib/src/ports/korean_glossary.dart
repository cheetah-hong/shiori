import 'package:shiori_core/src/models/list_equality.dart';

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
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  });

  /// Where the meanings come from, for the 정보 screen. Empty without data.
  List<GlossarySourceInfo> get sources;
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
  }) async => const [];

  @override
  List<GlossarySourceInfo> get sources => const [];
}
