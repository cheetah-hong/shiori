// Parity with the frozen reference parser, entry by entry.
// reference_output.json is produced by tools/reference/dump_reference.py.
import 'dart:io';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

const _templateIds = {'list': 'vocab.list', 'entry': 'vocab.entry'};

void main() {
  _parity(synthetic);
  group(
    'recorded textbook pages (local only)',
    skip: skipUnlessPresent(recordedTextbook),
    () => _parity(recordedTextbook),
  );
}

void _parity(FixtureSet set) {
  // A skipped group still runs its body to declare its tests: read nothing then.
  if (!set.exists) {
    test('(no data: placeholder for the skipped group)', () {});
    return;
  }
  if (!File('${set.dir}/reference_output.json').existsSync()) {
    test('reference_output.json is present', () {
      fail(
        'missing ${set.dir}/reference_output.json: run '
        'python3 tools/reference/dump_reference.py --data <that folder> '
        '(for the synthetic pages: python3 tools/synthetic/make_pages.py)',
      );
    });
    return;
  }
  final reference = set.readJson('reference_output.json');
  final pages = (reference['pages']! as List).cast<Map<String, Object?>>();
  final pipeline = standardPipeline();

  for (final page in pages) {
    final fixture = page['fixture']! as String;

    group(fixture, () {
      late CaptureDraft draft;
      final expected = (page['entries']! as List).cast<Map<String, Object?>>();

      setUpAll(
        () async =>
            draft = await pipeline.fromScan(await set.loadScan(fixture)),
      );

      test('same template and page meta', () {
        final meta = (page['meta']! as Map).cast<String, Object?>();
        expect(draft.templateId, _templateIds[page['template']]);
        expect(
          draft.meta,
          PageMeta(
            day: meta['day'] as int?,
            title: meta['title'] as String?,
            page: meta['page'] as int?,
          ),
        );
      });

      test('same entries in the same order', () {
        expect(draft.entries.map((e) => e.no), expected.map((e) => e['no']));
        for (final (i, want) in expected.indexed) {
          final got = draft.entries[i];
          final example = want['example'] as Map?;
          final label = '$fixture #${want['no']}';
          expect(got.headword, want['headword'], reason: label);
          expect(
            got.readings,
            (want['readings']! as List).cast<String>(),
            reason: label,
          );
          expect(got.pos?.badge, want['pos'], reason: label);
          expect(got.meaning, want['meaning'], reason: label);
          expect(got.important, want['important'], reason: label);
          expect(got.example?.ja, example?['ja'], reason: label);
          expect(got.example?.ko, example?['ko'], reason: label);
          expect(
            got.issues.map((i) => i.code),
            (want['issues']! as List).cast<String>(),
            reason: label,
          );
        }
      });
    });
  }
}
