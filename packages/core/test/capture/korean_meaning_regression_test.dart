// K12: the synthetic score tables with the meaning filler fed by a glossary.
// The only empty meaning on the synthetic pages is s011 0022 (鼻, はな, 코):
// OCR read its row without the meaning cell.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Answers [words] for every headword (or only for those in [only]).
final class _FixedGlossary implements KoreanGlossary {
  const _FixedGlossary(this.words, {this.only});

  final List<String> words;
  final Set<String>? only;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  }) async => only == null || only!.contains(headword)
      ? [KoreanSense(words: words, source: GlossarySource.krdict)]
      : const [];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

Future<CaptureScore> _score(FixtureSet set, KoreanGlossary glossary) =>
    scoreCapture(
      truth: set.truth,
      loadScan: set.loadScan,
      pipeline: CapturePipeline.standard(glossary: glossary),
    );

Map<String, ({int ok, int of})> _totals(CaptureScore s) => {
  for (final f in [...scoredFields, 'row', 'found']) f: s.total(f),
};

void main() {
  group('a glossary that answers every word', () {
    // Proves no meaning read from a page is replaced: a made-up answer for
    // every headword changes nothing but the one empty cell.
    const everything = _FixedGlossary(['사전뜻']);

    for (final set in [synthetic, syntheticMlKit]) {
      test('${set.name}: same totals as without a glossary', () async {
        final without = await _score(set, const EmptyKoreanGlossary());
        final withAll = await _score(set, everything);
        expect(_totals(withAll), _totals(without));
        expect(withAll.extras, 0);
        expect(withAll.silentErrors, without.silentErrors);
      });
    }

    test('synthetic: rows 31/35, ML Kit: rows 16/18', () async {
      expect((await _score(synthetic, everything)).total('row'), (
        ok: 31,
        of: 35,
      ));
      expect((await _score(syntheticMlKit, everything)).total('row'), (
        ok: 16,
        of: 18,
      ));
    });

    test('only the empty meaning differs from the reference output', () async {
      final found = await referenceDifferences(
        reference: synthetic.readJson('reference_output.json'),
        loadScan: synthetic.loadScan,
        pipeline: CapturePipeline.standard(glossary: everything),
      );
      final r = compareWithIntended(found, readIntendedDifferences(synthetic));
      expect(r.stale, isEmpty);
      // The meaning cell and its flag (missing → a dictionary guess).
      expect(
        [for (final d in r.unexpected) '${d.fixture} ${d.no} ${d.field}'],
        ['s011 0022 meaning', 's011 0022 issues'],
      );
      expect(r.unexpected.first.dart, '사전뜻');
      expect(r.unexpected.last.reference, ['meaning:missing']);
      expect(r.unexpected.last.dart, ['meaning:inferred']);
    });
  });

  group('the answer the Basic Korean Dictionary gives (鼻 → 코)', () {
    const nose = _FixedGlossary(['코'], only: {'鼻'});

    test('synthetic: meaning 33 → 34/35, rows 31 → 32/35', () async {
      final s = await _score(synthetic, nose);
      expect(s.total('meaning'), (ok: 34, of: 35));
      expect(s.total('row'), (ok: 32, of: 35));
      expect(s.extras, 0);
      expect(s.silentErrors, 1, reason: 'the misread 구룸, as before');
      expect(s.flaggedOk, 5, reason: 'four corrected headwords and 코');
    });

    test('ML Kit: no empty meaning, so 16/18 as before', () async {
      final s = await _score(syntheticMlKit, nose);
      expect(s.total('meaning'), (ok: 17, of: 18));
      expect(s.total('row'), (ok: 16, of: 18));
      expect(s.extras, 0);
    });
  });
}
