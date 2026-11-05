// Measurements of the Korean glossary on word lists and capture fixtures.
//
//   dart run tool/measure_glossary.dart coverage --db FILE --jlpt DIR
//   dart run tool/measure_glossary.dart precision --db FILE --gt FILE [--gt FILE …] [--verbose]
//   dart run tool/measure_glossary.dart capture --db FILE --fixtures DIR [--gt FILE] [--verbose]
//
// --db: the glossary SQLite file (gunzip app/assets/dict/ko-glossary.sqlite.gz).
// coverage: n5.csv, n4.csv, n3.csv in --jlpt (columns expression, reading; the
//   open JLPT decks), share of words with at least one meaning.
// precision: entries of ground_truth.json files (headword, readings, meaning):
//   share whose answer has a word in the first meaning, and in the first three.
// capture: the score table without and with the meaning filler.
// --verbose prints one line per word; on textbook data those quote the pages,
// so keep them out of anything committed.
import 'dart:convert';
import 'dart:io';

import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? '' : args.first;
  final db = _option(args, '--db');
  if (db == null ||
      !const {'coverage', 'precision', 'capture'}.contains(command)) {
    stderr.writeln('usage: (coverage|precision|capture) --db FILE …');
    exitCode = 2;
    return;
  }
  final glossary = KrdictGlossary.open(db);
  try {
    switch (command) {
      case 'coverage':
        _coverage(glossary, _option(args, '--jlpt') ?? '.');
      case 'precision':
        _precision(
          glossary,
          _options(args, '--gt'),
          args.contains('--verbose'),
        );
      case 'capture':
        await _capture(glossary, args);
    }
  } finally {
    glossary.close();
  }
}

// ---------------------------------------------------------------- coverage

void _coverage(KrdictGlossary g, String dir) {
  for (final level in ['n5', 'n4', 'n3']) {
    final file = File('$dir/$level.csv');
    if (!file.existsSync()) {
      stderr.writeln('missing ${file.path}');
      continue;
    }
    final rows = _csv(file.readAsStringSync()).skip(1).toList();
    var hit = 0;
    final watch = Stopwatch()..start();
    for (final r in rows) {
      final spellings = _variants(r[0]);
      final readings = _variants(r.length > 1 ? r[1] : '');
      if (spellings.any(
        (s) => g.lookupSync(s, readings: readings).isNotEmpty,
      )) {
        hit++;
      }
    }
    watch.stop();
    stdout.writeln(
      '${level.toUpperCase()}: $hit/${rows.length} '
      '(${(100 * hit / rows.length).toStringAsFixed(1)}%), '
      '${(watch.elapsedMicroseconds / rows.length).toStringAsFixed(0)} µs/word',
    );
  }
}

/// `会う; 逢う` or `ああ、あー` → each spelling.
List<String> _variants(String cell) => [
  for (final v in cell.split(RegExp('[;；、,]')))
    if (v.trim().isNotEmpty) v.trim(),
];

/// Comma-separated values with double-quoted fields.
List<List<String>> _csv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else if (c != '\r') {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) rows.add([...row, field.toString()]);
  return rows;
}

// ---------------------------------------------------------------- precision

void _precision(KrdictGlossary g, List<String> truthFiles, bool verbose) {
  var total = 0, found = 0, first = 0, firstLoose = 0, top3 = 0, top3Loose = 0;
  var lookups = 0;
  final watch = Stopwatch();
  final lines = <String>[];
  for (final path in truthFiles) {
    final truth = GroundTruth.fromJson(
      (jsonDecode(File(path).readAsStringSync()) as Map)
          .cast<String, Object?>(),
    );
    for (final page in truth.pages) {
      for (final e in page.entries) {
        if (e.headword.isEmpty || e.meaning.trim().isEmpty) continue;
        total++;
        watch.start();
        final senses = g.lookupSync(e.headword, readings: e.readings);
        watch.stop();
        lookups++;
        if (senses.isNotEmpty) found++;
        final answer = _answerWords(e.meaning);
        bool strict(KoreanSense s) => s.words.map(_norm).any(answer.contains);
        bool loose(KoreanSense s) => s.words.any((w) => _looseHit(w, answer));
        if (senses.isNotEmpty && strict(senses.first)) first++;
        if (senses.isNotEmpty && loose(senses.first)) firstLoose++;
        if (senses.any(strict)) top3++;
        if (senses.any(loose)) top3Loose++;
        if (verbose && !(senses.isNotEmpty && strict(senses.first))) {
          lines.add(
            '${page.page} ${e.no} ${e.headword}|${e.readings.join('/')} '
            'answer=${e.meaning} got=${[for (final s in senses) s.text]}',
          );
        }
      }
    }
  }
  String pct(int n) => '$n/$total (${(100 * n / total).toStringAsFixed(1)}%)';
  stdout
    ..writeln(
      'entries with a meaning: $total; any meaning found: ${pct(found)}',
    )
    ..writeln('answer word in meaning 1: ${pct(first)}; within 3: ${pct(top3)}')
    ..writeln(
      'loose (하다/되다/적/스럽다 endings, spaces): meaning 1 ${pct(firstLoose)}; '
      'within 3 ${pct(top3Loose)}',
    )
    ..writeln(
      'lookup: ${(watch.elapsedMicroseconds / lookups).toStringAsFixed(0)} µs '
      'each, ${lookups == 0 ? 0 : (watch.elapsedMicroseconds / 1000 / truthFiles.length).toStringAsFixed(1)} ms per file',
    );
  for (final l in lines) {
    stdout.writeln('  $l');
  }
}

/// `갈아타다, 환승하다` or `(교통) 정체` → {갈아타다, 환승하다} / {정체}.
Set<String> _answerWords(String meaning) => {
  for (final w
      in meaning
          .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
          .split(RegExp('[,，、/·;~]')))
    if (_norm(w).isNotEmpty) _norm(w),
};

String _norm(String w) => w.replaceAll(RegExp(r'\s+'), '').trim();

const _endings = ['하다', '되다', '적', '스럽다', '히', '이다'];

bool _looseHit(String word, Set<String> answer) {
  final w = _norm(word);
  return answer.any(
    (a) =>
        a == w ||
        _endings.any((e) => a == '$w$e' || w == '$a$e') ||
        (a.length >= 2 &&
            w.length >= 2 &&
            (a.startsWith(w) || w.startsWith(a))),
  );
}

// ---------------------------------------------------------------- capture

Future<void> _capture(KrdictGlossary g, List<String> args) async {
  final dir = _option(args, '--fixtures') ?? '../core/test/fixtures/synthetic';
  final truthFile = File(_option(args, '--gt') ?? '$dir/ground_truth.json');
  final verbose = args.contains('--verbose');
  final truth = GroundTruth.fromJson(
    (jsonDecode(truthFile.readAsStringSync()) as Map).cast<String, Object?>(),
  );
  final recognizer = FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  );
  Future<OcrScan> load(String fixture) =>
      recognizer.recognize(PageImage(fixture));
  final off = CapturePipeline.standard();
  final on = CapturePipeline.standard(glossary: g);
  final before = await scoreCapture(
    truth: truth,
    loadScan: load,
    pipeline: off,
  );
  final after = await scoreCapture(truth: truth, loadScan: load, pipeline: on);
  stdout
    ..writeln('== meaning filler off')
    ..writeln(before.table())
    ..writeln()
    ..writeln('== meaning filler on')
    ..writeln(after.table());
  var filled = 0;
  final lines = <String>[];
  final watch = Stopwatch();
  for (final page in truth.pages) {
    final scan = await load(page.fixture);
    watch.start();
    final draft = await on.fromScan(scan);
    watch.stop();
    for (final e in draft.entries) {
      if (!e.issues.any(
        (i) => i.field == EntryField.meaning && i.kind == IssueKind.inferred,
      )) {
        continue;
      }
      filled++;
      final answer = page.entries.where((t) => t.no == e.no).firstOrNull;
      lines.add(
        '${page.page} ${e.no} ${e.headword} filled=${e.meaning} '
        'answer=${answer?.meaning}',
      );
    }
  }
  stdout.writeln(
    'meanings filled: $filled; pipeline with the glossary: '
    '${(watch.elapsedMicroseconds / 1000 / truth.pages.length).toStringAsFixed(1)} ms/page',
  );
  if (verbose) {
    for (final l in lines) {
      stdout.writeln('  $l');
    }
  }
}

// ---------------------------------------------------------------- options

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i < 0 || i + 1 >= args.length ? null : args[i + 1];
}

List<String> _options(List<String> args, String name) => [
  for (var i = 0; i < args.length - 1; i++)
    if (args[i] == name) args[i + 1],
];
