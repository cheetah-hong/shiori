// Score table of the layout-free word extractor with the real JMdict, next
// to the extractor without a dictionary and the textbook row templates.
//
//   dart run tool/eval_extract_dict.dart --db FILE [--fixtures DIR] [--gt FILE]
//       [--glosses FILE] [--template] [--verbose]
//
// --db: a JMdict SQLite file (tools/dict/build_jmdict_db.py; the app's asset
// app/assets/dict/jmdict-full-lean.sqlite.gz, unzipped). Not committed.
// --fixtures, --gt, --glosses, --template, --verbose: as in
// packages/core/tool/eval_extract.dart (default fixtures: the synthetic pages
// for the extractor). Recorded textbook pages are local only, under
// "$SHIORI_PRIVATE_DIR/textbook"; --verbose quotes them.
import 'dart:convert';
import 'dart:io';

import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final dbPath = _option(args, '--db');
  if (dbPath == null || !File(dbPath).existsSync()) {
    stderr.writeln('--db FILE (a JMdict SQLite file) is required');
    exitCode = 2;
    return;
  }
  final dir =
      _option(args, '--fixtures') ?? '../core/test/fixtures/synthetic_general';
  final truthFile = File(_option(args, '--gt') ?? '$dir/ground_truth.json');
  if (!truthFile.existsSync()) {
    stderr.writeln('answers not found: ${truthFile.path}');
    exitCode = 2;
    return;
  }
  final glossPath = _option(args, '--glosses');
  final glosses = glossPath == null ? null : _glosses(File(glossPath));
  final truth = ExtractTruth.fromAnyJson(_json(truthFile));
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  Future<OcrScan> load(String fixture) =>
      recognizer.recognize(PageImage(fixture));
  final verbose = args.contains('--verbose');
  final jmdict = JmdictDictionary.open(dbPath);
  try {
    stdout.writeln(
      'dictionary: ${jmdict.info.entries}/${jmdict.info.glosses} '
      'JMdict ${jmdict.info.jmdictCreated}',
    );
    final runs = {
      'general, JMdict${glossPath == null ? '' : ', glosses'}': generalRun(
        GeneralExtractor(
          lexicon: JmdictLexiconAdapter(jmdict),
          koreanGlosses: glosses,
        ),
      ),
      'general, no dictionary': generalRun(GeneralExtractor()),
      if (args.contains('--template'))
        'template (row templates, JMdict)': templateRun(
          CapturePipeline.standard(dictionary: JmdictDictionaryAdapter(jmdict)),
        ),
    };
    for (final MapEntry(key: name, value: run) in runs.entries) {
      final score = await scoreExtractor(
        truth: truth,
        loadScan: load,
        run: run,
      );
      stdout
        ..writeln()
        ..writeln('== $name')
        ..writeln(score.table(verbose: verbose));
    }
  } finally {
    jmdict.close();
  }
}

Map<String, Object?> _json(File f) =>
    (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();

KoreanGlossLookup _glosses(File f) {
  final table = switch (_json(f)['glosses']) {
    final Map<String, Object?> m => {
      for (final MapEntry(:key, :value) in m.entries)
        key: [for (final g in value! as List) g as String],
    },
    _ => throw FormatException('${f.path}: needs a "glosses" object'),
  };
  return (headword, readings) async => table[headword] ?? const [];
}

/// The value after [name]; exits with a usage error when it is missing.
String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0) return null;
  if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
    stderr.writeln('$name needs a value');
    exit(2);
  }
  return args[i + 1];
}
