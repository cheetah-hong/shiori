import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// No POS badge was read: guess it from the headword, and say so.
///
/// Kanji followed by u-row okurigana (`降りる`, `包む`) is a verb; kanji only
/// (`切符`) is a noun. Anything else stays empty (flagged as missing later).
final class PosInferenceCorrector implements EntryCorrector {
  const PosInferenceCorrector();

  static const String _uRow = 'うくぐすつぬぶむる';

  @override
  String get id => 'pos-inference';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    if (entry.pos != null) return entry;
    final pos = inferPos(entry.headword);
    if (pos == null) return entry;
    return entry.copyWith(
      pos: pos,
      issues: [
        ...entry.issues,
        EntryIssue.inferred(EntryField.pos, note: '품사 추정: ${pos.badge}'),
      ],
    );
  }

  static PartOfSpeech? inferPos(String headword) {
    final runes = headword.runes.toList();
    if (runes.length >= 2 &&
        runes.any(isKanji) &&
        _uRow.runes.contains(runes.last)) {
      return PartOfSpeech.verb;
    }
    if (runes.isNotEmpty && runes.every(isKanji)) return PartOfSpeech.noun;
    return null;
  }
}
