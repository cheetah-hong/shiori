// W4: the Wiktionary fallback glossary file (build_wikt_glossary.py, same
// schema as the Basic Korean Dictionary file) read by the same block.
// Built from made-up samples: tools/dict/testdata/wikt_sample_*.jsonl.
import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// `python3 tools/dict/build_wikt_glossary.py --sample-sql`.
const _miniWiktSql = 'test/fixtures/mini_wikt.sql';

KrdictGlossary _open() => KrdictGlossary.fromDatabase(
  sqlite3.openInMemory()..execute(File(_miniWiktSql).readAsStringSync()),
);

void main() {
  late KrdictGlossary g;
  setUp(() => g = _open());
  tearDown(() => g.close());

  test(
    'the file has the current schema and names Wiktionary as its source',
    () {
      expect(g.hasPos, isTrue);
      final info = g.sources.single;
      expect(info.source, GlossarySource.wiktionary);
      expect(info.license, 'CC BY-SA 4.0');
      expect(info.edition, '2026-11-01');
      expect(info.publisher, isNotEmpty);
    },
  );

  test('a sense keeps its words together, in order, from Wiktionary', () async {
    final got = await g.lookup('雪森', readings: ['ゆきもり'], limit: 5);
    expect([for (final s in got) s.text], ['눈숲, 설삼', '겨울 숲']);
    expect({for (final s in got) s.source}, {GlossarySource.wiktionary});
    expect([for (final s in got) s.senseNo], [1, 2]);
  });

  test('a reading that is not the word\'s finds nothing', () async {
    expect(await g.lookup('雪森', readings: ['せっしん']), isEmpty);
  });

  test('a word written with okurigana is found by its whole reading', () async {
    final got = await g.lookup('雪森る', readings: ['ゆきもりる']);
    expect([for (final s in got) s.text], ['눈으로 덮다']);
    expect(await g.lookup('雪森る', readings: ['ゆきもりふ']), isEmpty);
  });

  test('the glossary\'s key rules: an ending, a katakana word', () async {
    expect([for (final s in await g.lookup('風森だ')) s.text], ['바람차다']);
    expect([for (final s in await g.lookup('風森')) s.text], ['바람차다']);
    expect([for (final s in await g.lookup('ユキヤマ')) s.text], ['눈산']);
  });

  test('an English Wiktionary row: the Korean words of the sense', () async {
    expect(
      [
        for (final s in await g.lookup('月道', readings: ['つきみち'])) s.text,
      ],
      ['달길, 월로'],
    );
    expect([for (final s in await g.lookup('月路')) s.text], ['달길, 월로']);
  });

  test('a word the Basic Korean Dictionary has is not in the file', () async {
    expect(await g.lookup('静森', readings: ['しずもり']), isEmpty);
    expect(await g.lookup('しずもり'), isEmpty);
    expect(await g.lookup('星波'), isEmpty);
  });

  test('a limit cuts the senses', () async {
    expect(await g.lookup('雪森', readings: ['ゆきもり'], limit: 1), hasLength(1));
  });
}
