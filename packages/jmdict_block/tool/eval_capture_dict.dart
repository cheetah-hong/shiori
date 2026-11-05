// The capture score table with the JMdict block plugged into the core
// pipeline, next to the same table without a dictionary.
//
//   dart run tool/eval_capture_dict.dart --db FILE [--fixtures DIR] [--gt FILE]
//       [--verbose]
//
// --db: a JMdict SQLite file (tools/dict/build_jmdict_db.py; the app's asset is
// full-lean). Without it only the no-dictionary table is printed.
// --fixtures, --gt: as in packages/core/tool/eval_capture.dart. The
// recorded textbook pages are local only, under "$SHIORI_PRIVATE_DIR/textbook".
// --verbose prints one line per affected entry; those quote the pages, so keep
// them out of anything committed.
import 'dart:convert';
import 'dart:io';

import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final removed = [
    for (final o in const ['--stars', '--star-ratios'])
      if (args.contains(o)) o,
  ];
  if (removed.isNotEmpty) {
    stderr.writeln(
      '${removed.join(', ')}: removed (the textbook ★ is no longer read)',
    );
    exitCode = 2;
    return;
  }
  final verbose = args.contains('--verbose');
  final dir = _option(args, '--fixtures') ?? '../core/test/fixtures/synthetic';
  final truthFile = File(_option(args, '--gt') ?? '$dir/ground_truth.json');
  final dbPath = _option(args, '--db');
  if (!truthFile.existsSync()) {
    stderr.writeln('ground truth not found: ${truthFile.path}');
    exitCode = 2;
    return;
  }
  final truth = GroundTruth.fromJson(
    (jsonDecode(truthFile.readAsStringSync()) as Map).cast<String, Object?>(),
  );
  final load = _scanLoader(dir);

  JmdictDictionaryAdapter? jmdict;
  if (dbPath != null) {
    jmdict = JmdictDictionaryAdapter(JmdictDictionary.open(dbPath));
    stdout.writeln(
      'dictionary: ${jmdict.info.entries}/${jmdict.info.glosses} '
      'JMdict ${jmdict.info.jmdictCreated} '
      'source sha256 ${jmdict.info.sourceSha256.substring(0, 16)}…',
    );
  }
  try {
    final off = CapturePipeline.standard();
    stdout
      ..writeln('== dictionary off')
      ..writeln(
        (await scoreCapture(
          truth: truth,
          loadScan: load,
          pipeline: off,
        )).table(verbose: verbose),
      );
    if (jmdict == null) return;
    final on = CapturePipeline.standard(dictionary: jmdict);
    stdout
      ..writeln()
      ..writeln('== dictionary on')
      ..writeln(
        (await scoreCapture(
          truth: truth,
          loadScan: load,
          pipeline: on,
        )).table(verbose: verbose),
      )
      ..writeln()
      ..writeln(
        (await _dictionaryEffect(truth, load, off, on)).report(verbose),
      );
  } finally {
    jmdict?.close();
  }
}

Future<OcrScan> Function(String) _scanLoader(String dir) {
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  return (fixture) => recognizer.recognize(PageImage(fixture));
}

/// What the dictionary did, entry by entry, against the answers.
final class _Effect {
  int rightHeadwords = 0;
  int unverifiedRight = 0;
  int unverifiedWrong = 0;
  int fixedRight = 0;
  int fixedWrong = 0;
  int newlyCaught = 0;
  int newlyToCheck = 0;
  final List<int?> candidateRanks = [];
  final List<String> lines = [];

  String report(bool verbose) {
    final b = StringBuffer()
      ..writeln(
        'right headword marked 사전에 없음 (false alarms): '
        '$unverifiedRight/$rightHeadwords',
      )
      ..writeln('wrong headword marked 사전에 없음: $unverifiedWrong')
      ..writeln(
        'headword changed by the dictionary: right $fixedRight, wrong $fixedWrong',
      )
      ..writeln(
        'core errors silent without the dictionary, flagged with it: '
        '$newlyCaught',
      )
      ..writeln(
        'core errors not 확인 필요 without the dictionary, 확인 필요 with it: '
        '$newlyToCheck',
      )
      ..write(
        'unread headwords: ${candidateRanks.length}; rank of the answer among '
        'the candidates: ${candidateRanks.map((r) => r ?? '-').join(', ')}',
      );
    if (verbose) {
      for (final l in lines) {
        b.write('\n  $l');
      }
    }
    return b.toString();
  }
}

Future<_Effect> _dictionaryEffect(
  GroundTruth truth,
  Future<OcrScan> Function(String) load,
  CapturePipeline off,
  CapturePipeline on,
) async {
  final effect = _Effect();
  for (final page in truth.pages) {
    final scan = await load(page.fixture);
    final withoutDict = {
      for (final e in (await off.fromScan(scan)).entries) e.no: e,
    };
    final withDict = {
      for (final e in (await on.fromScan(scan)).entries) e.no: e,
    };
    for (final g in page.entries) {
      final e = withDict[g.no];
      final before = withoutDict[g.no];
      if (e == null || before == null) continue;
      final right = e.headword == g.headword;
      final unverified =
          e.statusOf(EntryField.headword) == FieldStatus.unverified;
      if (right) effect.rightHeadwords++;
      if (unverified) {
        right ? effect.unverifiedRight++ : effect.unverifiedWrong++;
        effect.lines.add('${page.page} ${g.no} 사전에 없음 got=${e.headword}');
      }
      if (e.headword != before.headword) {
        right ? effect.fixedRight++ : effect.fixedWrong++;
        effect.lines.add(
          '${page.page} ${g.no} ${before.headword} → ${e.headword} '
          '(${right ? 'right' : 'wrong'})',
        );
      }
      if (before.headword.isEmpty) {
        final i = e.headwordCandidates.indexOf(g.headword);
        effect.candidateRanks.add(i < 0 ? null : i + 1);
        effect.lines.add(
          '${page.page} ${g.no} candidates=${e.headwordCandidates}',
        );
      }
      if (!_coreOk(before, g) && !before.isFlagged && e.isFlagged) {
        effect.newlyCaught++;
      }
      if (!_coreOk(before, g) && !before.needsReview && e.needsReview) {
        effect.newlyToCheck++;
      }
    }
  }
  return effect;
}

bool _coreOk(CapturedEntry e, GroundTruthEntry g) =>
    e.headword == g.headword &&
    e.readings.join('/') == g.readings.join('/') &&
    e.meaning.replaceAll(RegExp(r'\s+'), '') ==
        g.meaning.replaceAll(RegExp(r'\s+'), '');

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
