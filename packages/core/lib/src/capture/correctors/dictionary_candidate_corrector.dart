import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/dictionary.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// When OCR skipped a headword (simple kanji such as `日`, `空`), offers the
/// dictionary's words for the reading. The learner still confirms the choice.
///
/// The POS badge goes along as a hint (it reorders, never filters). The
/// headword stays empty: the learner picks a candidate on the review screen.
/// With `EmptyDictionary` this does nothing.
final class DictionaryCandidateCorrector implements EntryCorrector {
  const DictionaryCandidateCorrector(this.dictionary, {this.limit = 5});

  final Dictionary dictionary;
  final int limit;

  @override
  String get id => 'dictionary-candidates';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    if (entry.headword.isNotEmpty || entry.readings.isEmpty) return entry;
    final found = await dictionary.byReading(
      entry.readings.first,
      limit: limit,
      pos: entry.pos,
    );
    final candidates = {for (final d in found) d.headword}.toList();
    return candidates.isEmpty
        ? entry
        : entry.copyWith(headwordCandidates: candidates);
  }
}
