// Score table of the layout-free word extractor, by headword.
//
//   dart run tool/eval_extract.dart [--fixtures DIR] [--gt FILE]
//       [--lexicon FILE] [--glosses FILE] [--verbose] [--no-warmup]
//
// DIR defaults to the synthetic pages for the extractor
// (test/fixtures/synthetic_general); --gt to DIR/ground_truth.json
// (`"format": "general-1"`). --lexicon: an
// in-memory dictionary file (default DIR/lexicon.json when it exists; none
// otherwise). With the real JMdict use packages/jmdict_block/tool/eval_extract_dict.dart.
// --glosses: a {"glosses": {headword: [Korean, ...]}} file standing in for a
// Korean gloss dictionary.
// --verbose lists every mistake; on recorded textbook pages those quote the
// page, so keep them out of anything committed.
// Times per page come after one untimed read of the first page (the VM's
// warm-up and the dictionary's first reads); --no-warmup times it cold.
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final dir = _option(args, '--fixtures') ?? 'test/fixtures/synthetic_general';
  final truthFile = File(_option(args, '--gt') ?? '$dir/ground_truth.json');
  if (!truthFile.existsSync()) {
    stderr.writeln('answers not found: ${truthFile.path}');
    exitCode = 2;
    return;
  }
  final lexiconPath = _option(args, '--lexicon') ?? '$dir/lexicon.json';
  final lexicon = File(lexiconPath).existsSync()
      ? InMemoryLexicon.fromJson(_json(File(lexiconPath)))
      : null;
  final glossPath = _option(args, '--glosses');
  final glosses = glossPath == null ? null : _glosses(File(glossPath));
  final truth = ExtractTruth.fromJson(_json(truthFile));
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  Future<OcrScan> load(String fixture) =>
      recognizer.recognize(PageImage(fixture));
  final verbose = args.contains('--verbose');
  // Per-page times after one warm-up read of the first page (VM warm-up,
  // the dictionary files' first reads); --no-warmup gives the cold first page.
  final warmUp = !args.contains('--no-warmup');

  final general = await scoreExtractor(
    truth: truth,
    loadScan: load,
    warmUp: warmUp,
    run: generalRun(
      GeneralExtractor(
        lexicon: lexicon ?? const EmptyLexicon(),
        koreanGlosses: glosses,
      ),
    ),
  );
  stdout
    ..writeln(
      '== general (lexicon: ${lexicon == null ? 'none' : lexiconPath}, '
      'glosses: ${glossPath ?? 'none'})',
    )
    ..writeln(general.table(verbose: verbose));
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
