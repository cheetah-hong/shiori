import 'package:shiori_core/src/capture/correctors/confusables.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// The reading is hiragana but OCR read katakana in the headword (`カム` for `力む`).
///
/// Walking from the end, characters that match the reading become hiragana
/// (okurigana) and look-alikes become kanji, until neither applies.
final class KanaOkuriganaCorrector implements EntryCorrector {
  const KanaOkuriganaCorrector();

  @override
  String get id => 'kana-okurigana';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    final h = entry.headword;
    final reading = entry.readings.isEmpty ? '' : entry.readings.first;
    if (reading.isEmpty ||
        !containsKata(h) ||
        !reading.runes.every(isHira) ||
        h.contains('ー')) {
      return entry;
    }
    final chars = h.runes.toList();
    final kana = reading.runes.toList();
    var k = kana.length - 1;
    for (var i = chars.length - 1; i >= 0; i--) {
      final c = chars[i];
      final hira = isKata(c) ? c - 0x60 : c;
      final lookAlike = confusableInKanji[c];
      if (k >= 0 && hira == kana[k]) {
        chars[i] = hira;
        k--;
      } else if (lookAlike != null) {
        chars[i] = lookAlike;
      } else {
        break;
      }
    }
    final fixed = String.fromCharCodes(chars);
    if (fixed == h) return entry;
    return entry.copyWith(
      headword: fixed,
      issues: [
        ...entry.issues,
        EntryIssue.corrected(EntryField.headword, note: '$h → $fixed'),
      ],
    );
  }
}
