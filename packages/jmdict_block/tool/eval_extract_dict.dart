// Score table of the layout-free word extractor with the real JMdict, next
// to the extractor without a dictionary and the textbook row templates.
//
//   dart run tool/eval_extract_dict.dart --db FILE [--fixtures DIR] [--gt FILE]
//       [--glosses FILE] [--glossary FILE] [--template] [--routed] [--verbose]
//       [--no-warmup]
//
// --glossary: the Korean glossary SQLite file (tools/dict/build_ko_glossary.py;
// the app's asset app/assets/dict/ko-glossary.sqlite.gz, unzipped), plugged
// into the extractor as a pairing signal and for meanings the page lacks.
// --routed also scores CaptureRouter (row template when it fits, general
// extractor otherwise), as the app reads pages.
//
// --db: a JMdict SQLite file (tools/dict/build_jmdict_db.py; the app's asset
// app/assets/dict/jmdict-full-lean.sqlite.gz, unzipped). Not committed.
// --fixtures, --gt, --glosses, --template, --verbose: as in
// packages/core/tool/eval_extract.dart (default fixtures: the synthetic pages
// for the extractor). Recorded textbook pages are local only, under
// "$SHIORI_PRIVATE_DIR/textbook"; --verbose quotes them.
// Times per page come after one untimed read of the first page (the VM's
// warm-up and the dictionary's first reads); --no-warmup times it cold.
import 'dart:convert';
import 'dart:io';

import 'package:jmdict_block/jmdict_block.dart';
import 'package:krdict_block/krdict_block.dart';
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
  // Per-page times after one warm-up read of the first page (VM warm-up,
  // the dictionary files' first reads); --no-warmup gives the cold first page.
  final warmUp = !args.contains('--no-warmup');
  final jmdict = JmdictDictionary.open(dbPath);
  final glossaryPath = _option(args, '--glossary');
  final glossary = glossaryPath == null
      ? null
      : KrdictGlossary.open(glossaryPath);
  try {
    stdout.writeln(
      'dictionary: ${jmdict.info.entries}/${jmdict.info.glosses} '
      'JMdict ${jmdict.info.jmdictCreated}',
    );
    final runs = {
      'general, JMdict${glossPath == null ? '' : ', glosses'}'
          '${glossary == null ? '' : ', glossary'}': generalRun(
        GeneralExtractor(
          lexicon: JmdictLexiconAdapter(jmdict),
          koreanGlosses: glosses,
          koreanGlossary: glossary,
        ),
      ),
      'general, no dictionary': generalRun(GeneralExtractor()),
      if (args.contains('--template'))
        'template (row templates, JMdict)': templateRun(
          CapturePipeline.standard(dictionary: JmdictDictionaryAdapter(jmdict)),
        ),
      if (args.contains('--routed'))
        'routed (template when it fits, else general)': routedRun(
          CaptureRouter(
            template: CapturePipeline.standard(
              dictionary: JmdictDictionaryAdapter(jmdict),
              glossary: glossary,
            ),
            general: GeneralExtractor(
              lexicon: JmdictLexiconAdapter(jmdict),
              koreanGlossary: glossary,
            ),
          ),
        ),
    };
    for (final MapEntry(key: name, value: run) in runs.entries) {
      final score = await scoreExtractor(
        truth: truth,
        loadScan: load,
        run: run,
        warmUp: warmUp,
      );
      stdout
        ..writeln()
        ..writeln('== $name')
        ..writeln(score.table(verbose: verbose));
    }
  } finally {
    glossary?.close();
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
