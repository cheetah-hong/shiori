// Added after the review: spaces are one explicit set on both sides
// (tools/dict/testdata/ko_glossary_keys_extra.json, also read by
// tools/dict/test_build_ko_glossary_extra.py).
import 'dart:convert';
import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:test/test.dart';

void main() {
  final cases =
      ((jsonDecode(
                    File(
                      '../../tools/dict/testdata/ko_glossary_keys_extra.json',
                    ).readAsStringSync(),
                  )
                  as Map)['cases']
              as List)
          .cast<Map<String, Object?>>();

  for (final c in cases) {
    test('${c['why']}', () {
      expect(pairKey(c['form']! as String, c['reading']! as String), (
        c['key']! as String,
        c['reading_key']! as String,
      ));
    });
  }
}
