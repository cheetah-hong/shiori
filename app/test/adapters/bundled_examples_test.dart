// X5 (app side): the example sentence asset is unpacked and opened like the
// dictionaries; without it (a debug build) the app runs without filled
// examples and logs one line.
import 'dart:convert';
import 'dart:io';

import 'package:example_block/example_block.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/bundled_examples.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;
import '../support/examples.dart';

void main() {
  late Directory support;
  late List<String> logs;

  setUp(() {
    support = Directory.systemTemp.createTempSync('shiori_examples_');
    logs = [];
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<BundledExamples> open(MemoryAssetBundle bundle) => openBundledExamples(
    bundle: bundle,
    supportDirectory: () async => support,
    log: logs.add,
  );

  Map<String, List<int>> assets({bool damaged = false}) {
    final db = miniExamplesFileBytes(support);
    final gz = gzip.encode(db);
    final shipped = damaged ? gz.sublist(0, gz.length ~/ 2) : gz;
    return {
      examplesAsset: shipped,
      examplesEditionAsset: utf8.encode(
        examplesEditionJson(sqlite: db, gz: shipped),
      ),
    };
  }

  test('the asset names', () {
    expect(examplesAsset, 'assets/dict/examples.sqlite.gz');
    expect(examplesEditionAsset, 'assets/dict/examples.edition.json');
    expect(examplesFileName, 'examples.sqlite');
  });

  test('with the asset: the sentences open, with their edition', () async {
    final opened = await open(MemoryAssetBundle(assets()));
    addTearDown(opened.close);

    expect(opened.isAvailable, isTrue);
    expect(opened.examples, isA<TatoebaExamples>());
    expect(opened.problem, isNull);
    expect(opened.edition?.edition, '2026-11-07');
    expect(opened.edition?.license, 'CC BY 2.0 FR');
    expect(opened.edition?.url, 'https://tatoeba.org');
    final rows = await opened.sentences.lookup([shizukaEntry]);
    expect(rows.single.ko, '조용히 하세요.');
    expect(File('${support.path}/$examplesFileName').existsSync(), isTrue);
  });

  test('without the asset: no sentences and one log line', () async {
    final opened = await open(MemoryAssetBundle({}));

    expect(opened.isAvailable, isFalse);
    expect(opened.problemKind, DictionaryProblem.missing);
    expect(opened.sentences, isA<EmptyExampleSentences>());
    expect(await opened.sentences.lookup([shizukaEntry]), isEmpty);
    expect(logs, hasLength(1));
  });

  test('a damaged asset: no sentences, damaged, one log line', () async {
    final opened = await open(MemoryAssetBundle(assets(damaged: true)));

    expect(opened.isAvailable, isFalse);
    expect(opened.problemKind, DictionaryProblem.damaged);
    expect(logs, hasLength(1));
    expect(File('${support.path}/$examplesFileName').existsSync(), isFalse);
  });

  test('an edition without its source is damaged', () async {
    final files = assets();
    files[examplesEditionAsset] = utf8.encode('{"built_on": "2026-11-12"}');
    final opened = await open(MemoryAssetBundle(files));
    expect(opened.problemKind, DictionaryProblem.damaged);
    expect(logs, hasLength(1));
  });
}
