// The cell-by-cell parity check itself: it must report every kind of change.
import 'dart:convert';

import 'package:shiori_core/eval.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

Map<String, Object?> _copy(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();

void main() {
  final pipeline = standardPipeline();
  late Map<String, Object?> reference;

  setUpAll(() => reference = synthetic.readJson('reference_output.json'));

  Future<List<CellDifference>> diff(Map<String, Object?> ref) =>
      referenceDifferences(
        reference: ref,
        loadScan: synthetic.loadScan,
        pipeline: pipeline,
      );

  Map<String, Object?> page(Map<String, Object?> ref, String fixture) =>
      (ref['pages']! as List).cast<Map<String, Object?>>().singleWhere(
        (p) => p['fixture'] == fixture,
      );

  test('the synthetic pages match the reference output cell by cell', () async {
    expect(await diff(reference), isEmpty);
  });

  test('reports changed cells, page cells and missing entries', () async {
    final ref = _copy(reference);
    final s140 = page(ref, 's140');
    s140['template'] = 'list';
    (s140['meta']! as Map)['day'] = 99;
    final entries = (s140['entries']! as List).cast<Map<String, Object?>>();
    entries[0]['headword'] = '乗り越える';
    entries[0]['readings'] = ['のりこえる'];
    (entries[1]['example']! as Map)['ko'] = '다른 번역';
    entries.removeAt(2);
    entries.add({...entries.last, 'no': '9999'});

    final found = await diff(ref);
    expect(found.map((d) => '${d.fixture} ${d.no} ${d.field}'), [
      's140 null template',
      's140 null meta',
      's140 1211 headword',
      's140 1211 readings',
      's140 1212 example.ko',
      's140 9999 entry',
      's140 1213 entry',
    ]);
    final readings = found.singleWhere((d) => d.field == 'readings');
    expect(readings.reference, ['のりこえる']);
    expect(readings.dart, ['のりかえる']);
    final missing = found.singleWhere((d) => d.no == '1213');
    expect((missing.reference, missing.dart), (false, true));
  });

  test('a repeated number is compared copy by copy', () async {
    final ref = _copy(reference);
    final entries = (page(ref, 's147')['entries']! as List)
        .cast<Map<String, Object?>>();
    entries.add({...entries.first});
    final found = await diff(ref);
    expect(found.single.no, '1271#2');
    expect(found.single.field, 'entry');
  });

  test('compareWithIntended: unexpected and stale cells', () {
    const a = CellDifference(
      fixture: 's010',
      no: '0001',
      field: 'headword',
      reference: '問雨',
      dart: '雨',
    );
    const b = CellDifference(
      fixture: 's010',
      no: '0002',
      field: 'pos',
      reference: null,
      dart: '명',
    );
    final listed = CellDifference.fromJson({
      ...a.toJson(),
      'reason': 'checkbox glyph removed',
    });
    final r = compareWithIntended([a, b], [listed]);
    expect(r.unexpected, [b]);
    expect(r.stale, isEmpty);
    expect(listed.reason, 'checkbox glyph removed');
    expect(compareWithIntended([], [listed]).stale, [listed]);
    expect('$b', 's010 #0002 pos: reference=null dart=명');
    expect(
      a.sameAs(
        const CellDifference(
          fixture: 's010',
          no: '0001',
          field: 'headword',
          reference: '問雨',
          dart: '雨!',
        ),
      ),
      isFalse,
    );
  });
}
