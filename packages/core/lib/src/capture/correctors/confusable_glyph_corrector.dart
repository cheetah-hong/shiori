import 'package:shiori_core/src/capture/correctors/confusables.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// `ー` → `一`, `+` → `十` (whole headword, only when a reading was read),
/// and a lone look-alike katakana inside a kanji word (`タ日` → `夕日`).
///
/// Only a katakana glyph with no other katakana next to it is changed: a run
/// of two or more is a real word (`アメリカ人`, `ローマ字`). A lone one can still
/// be real (`カ月`); with a dictionary, `DictionaryPairCorrector` undoes that.
/// A run made only of look-alikes (`ロロロ`, checkbox marks read as text) is
/// left as it is but flagged as suspect, so the learner looks at it.
final class ConfusableGlyphCorrector implements EntryCorrector {
  const ConfusableGlyphCorrector();

  @override
  String get id => 'confusable-glyphs';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    final h = entry.headword;
    final whole = confusableWhole[h];
    if (whole != null && entry.readings.isNotEmpty) {
      return _fixed(entry, whole);
    }
    if (!containsKanji(h)) return entry;
    final runes = h.runes.toList();
    final fixed = [
      for (final (i, c) in runes.indexed)
        _lone(runes, i) ? confusableInKanji[c] ?? c : c,
    ];
    final text = String.fromCharCodes(fixed);
    final out = text == h ? entry : _fixed(entry, text);
    final odd = _katakanaRuns
        .allMatches(text)
        .map((m) => m[0]!)
        .where((run) => run.runes.every(confusableInKanji.containsKey))
        .firstOrNull;
    return odd == null
        ? out
        : out.withIssue(
            EntryIssue.suspect(
              EntryField.headword,
              note: '헷갈리는 글자일 수 있음: $odd',
            ),
          );
  }

  /// Runs of two or more katakana (U+30A0–U+30FF, as `isKata`).
  static final RegExp _katakanaRuns = RegExp('[\u30A0-\u30FF]{2,}');

  /// Whether the katakana at [i] has no katakana on either side.
  static bool _lone(List<int> runes, int i) =>
      (i == 0 || !isKata(runes[i - 1])) &&
      (i == runes.length - 1 || !isKata(runes[i + 1]));

  CapturedEntry _fixed(CapturedEntry entry, String headword) => entry.copyWith(
    headword: headword,
    issues: [
      ...entry.issues,
      EntryIssue.corrected(
        EntryField.headword,
        note: '${entry.headword} → $headword',
      ),
    ],
  );
}
