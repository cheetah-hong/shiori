import 'package:shiori_core/src/models/captured_entry.dart';

/// Block slot: one link of the correction chain run on every captured entry.
///
/// Correctors run in order; each returns a new entry and records what it did
/// as an [EntryIssue]. First blocks: confusable glyphs, katakana okurigana,
/// missing-field flags. Next: dictionary candidates (JMdict).
abstract interface class EntryCorrector {
  String get id;

  Future<CapturedEntry> correct(CapturedEntry entry);
}
