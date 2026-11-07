import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/korean_glossary.dart';

/// A glossary that answers from [fallback] only for a word [primary] has no
/// sense for: for any other word the answer is [primary]'s, unchanged.
///
/// One word form at a time: the word extractor applies the same rule over
/// all of a word's forms itself (`GeneralExtractor.meaningFallback`,
/// docs/dictionary.md 13.4); measurements use this to ask the Basic Korean
/// Dictionary with the Wiktionary fallback glossary behind it.
final class FallbackKoreanGlossary implements KoreanGlossary {
  const FallbackKoreanGlossary(this.primary, this.fallback);

  final KoreanGlossary primary;
  final KoreanGlossary fallback;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    final found = await primary.lookup(
      headword,
      readings: readings,
      limit: limit,
      pos: pos,
    );
    if (found.isNotEmpty) return found;
    return fallback.lookup(
      headword,
      readings: readings,
      limit: limit,
      pos: pos,
    );
  }

  @override
  List<GlossarySourceInfo> get sources =>
      List.unmodifiable([...primary.sources, ...fallback.sources]);
}
