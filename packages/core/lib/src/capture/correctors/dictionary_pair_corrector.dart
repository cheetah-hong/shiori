import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/ports/dictionary.dart';
import 'package:shiori_core/src/ports/entry_corrector.dart';

/// Checks a read headword with its readings against the dictionary.
///
/// - Known (or no dictionary): nothing changes.
/// - A rule changed what OCR read, the result is not a word but the OCR text
///   is (`タ行` → `夕行`): back to the OCR text.
/// - Found only as two words in a row: kept (a weak match, nothing better).
/// - Look-alike glyphs explain the text (`ー日` → `一日`): fixed, with the
///   other fixes offered as candidates.
/// - Otherwise marked "사전에 없음" for the learner to check.
///
/// Runs after the rule correctors and before the missing-field flags.
final class DictionaryPairCorrector implements EntryCorrector {
  const DictionaryPairCorrector(this.dictionary);

  final Dictionary dictionary;

  @override
  String get id => 'dictionary-pair';

  @override
  Future<CapturedEntry> correct(CapturedEntry entry) async {
    final headword = entry.headword;
    if (headword.isEmpty) return entry; // DictionaryCandidateCorrector's job
    final status = await dictionary.checkPair(headword, entry.readings);
    if (status == PairStatus.known || status == PairStatus.unavailable) {
      return entry;
    }
    final ocr = entry.ocrHeadword ?? headword;
    if (ocr.isNotEmpty &&
        ocr != headword &&
        await dictionary.checkPair(ocr, entry.readings) == PairStatus.known) {
      return _fixed(entry, ocr, from: headword);
    }
    if (status == PairStatus.compoundOnly) return entry;
    final fixes = await dictionary.fixHeadword(
      ocr,
      entry.readings.isEmpty ? '' : entry.readings.first,
      pos: entry.pos,
    );
    if (fixes.isNotEmpty) {
      return _fixed(entry, fixes.first, from: ocr, candidates: fixes);
    }
    return entry.withIssue(const EntryIssue.unverified(EntryField.headword));
  }

  /// One "자동 보정됨 (사전)" note replaces the rules' notes on the headword.
  static CapturedEntry _fixed(
    CapturedEntry entry,
    String headword, {
    required String from,
    List<String>? candidates,
  }) => entry.copyWith(
    headword: headword,
    headwordCandidates: candidates,
    issues: [
      for (final i in entry.issues)
        if (!(i.field == EntryField.headword && i.kind == IssueKind.corrected))
          i,
      EntryIssue.corrected(EntryField.headword, note: '$from → $headword (사전)'),
    ],
  );
}
