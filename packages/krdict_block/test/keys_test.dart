// K9: the same index keys as tools/dict/build_ko_glossary.py.
import 'dart:convert';
import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:test/test.dart';

import 'support/mini.dart';

void main() {
  final cases =
      ((jsonDecode(File(keyTable).readAsStringSync()) as Map)['cases'] as List)
          .cast<Map<String, Object?>>();

  test('the shared table has its cases', () {
    expect(cases.length, greaterThanOrEqualTo(20));
  });

  for (final c in cases) {
    final form = c['form']! as String;
    final reading = c['reading']! as String;
    test('${c['why']}: "$form" / "$reading"', () {
      expect(pairKey(form, reading), (
        c['key']! as String,
        c['reading_key']! as String,
      ));
    });
  }
}
