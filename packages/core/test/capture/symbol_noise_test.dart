// ★ ☆ * ＊ printed or misread on a page carry no meaning for the learner: the
// clean-up cuts them out of the OCR lines before any template reads a cell.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

final RegExp _symbol = RegExp('[★☆*＊]');

void main() {
  final pipeline = standardPipeline();
  final drafts = <String, CaptureDraft>{};
  final truths = <String, GroundTruthPage>{};

  setUpAll(() async {
    for (final (set, pages) in [
      (synthetic, ['s010', 's011', 's140', 's147']),
      (syntheticMlKit, ['m011', 'm140']),
    ]) {
      for (final page in pages) {
        drafts[page] = await pipeline.fromScan(await set.loadScan(page));
      }
      for (final p in set.truth.pages) {
        truths[p.fixture] = p;
      }
    }
  });

  CapturedEntry word(String page, String no) =>
      drafts[page]!.entries.singleWhere((e) => e.no == no);

  GroundTruthEntry truth(String page, String no) =>
      truths[page]!.entries.singleWhere((e) => e.no == no);

  test('no headword, reading or meaning holds ★ ☆ * ＊', () {
    for (final MapEntry(key: page, value: draft) in drafts.entries) {
      for (final e in draft.entries) {
        final cells = [e.headword, ...e.readings, e.meaning];
        for (final c in cells) {
          expect(c, isNot(contains(_symbol)), reason: '$page ${e.no}');
        }
      }
    }
  });

  test('glued or lone symbols leave headword and readings as printed', () {
    for (final (page, no) in [
      ('s140', '1211'), // 乗り換える★
      ('s147', '1272'), // 売り場 ★
      ('m011', '0015'), // ★かわ
      ('m011', '0019'), // * on its own line
      ('s011', '0015'), // ★ on its own line
    ]) {
      final e = word(page, no);
      final g = truth(page, no);
      expect(e.headword, g.headword, reason: '$page $no');
      expect(e.readings, g.readings, reason: '$page $no');
    }
  });

  test('the legend line (★三人=…) is not an entry', () {
    for (final draft in drafts.values) {
      for (final e in draft.entries) {
        expect(e.headword, isNot(contains('三人')), reason: '${e.no}');
      }
    }
    int count(List<String> pages) =>
        pages.fold(0, (n, p) => n + drafts[p]!.entries.length);
    expect(count(['s010', 's011', 's140', 's147']), 35);
    expect(count(['m011', 'm140']), 18);
  });
}
