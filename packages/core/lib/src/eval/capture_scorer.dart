import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/capture/capture_pipeline.dart';
import 'package:shiori_core/src/capture/text/chars.dart';
import 'package:shiori_core/src/capture/text/sequence_matcher.dart';
import 'package:shiori_core/src/eval/ground_truth.dart';
import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/ocr.dart';

/// Scores the capture pipeline against [GroundTruth], like `parse_eval.py`.
///
/// Examples count as correct at similarity ≥ [exampleThreshold] (difflib ratio).
const double exampleThreshold = 0.9;

const List<String> scoredFields = [
  'headword',
  'readings',
  'pos',
  'meaning',
  'important',
];

typedef Tally = ({int ok, int of});

final class PageScore {
  const PageScore({
    required this.page,
    required this.templateId,
    required this.size,
    required this.found,
    required this.fields,
    required this.rowsOk,
    required this.exampleJaOk,
    required this.exampleKoOk,
    required this.hasExamples,
    required this.meta,
    required this.metaOk,
    required this.mistakes,
  });

  final int page;
  final String templateId;
  final int size;
  final int found;
  final Map<String, int> fields;
  final int rowsOk;
  final int exampleJaOk;
  final int exampleKoOk;
  final bool hasExamples;
  final PageMeta meta;
  final bool metaOk;

  /// One line per wrong or flagged entry (the reference's `--verbose` output).
  final List<String> mistakes;
}

final class CaptureScore {
  const CaptureScore({
    required this.pages,
    required this.totals,
    required this.silentErrors,
    required this.flaggedWrong,
    required this.flaggedOk,
  });

  final List<PageScore> pages;
  final Map<String, Tally> totals;

  /// Headword, readings or meaning wrong and nothing shown on the review screen.
  final int silentErrors;
  final int flaggedWrong;
  final int flaggedOk;

  Tally total(String key) => totals[key] ?? (ok: 0, of: 0);

  /// Fixed-width score table, same columns as the reference.
  String table({bool verbose = false}) {
    final b = StringBuffer();
    if (verbose) {
      for (final p in pages) {
        for (final m in p.mistakes) {
          b.writeln('  ${p.page} $m');
        }
      }
    }
    b.writeln(
      'page tpl    n found head read  pos mean star  row exJA exKO meta',
    );
    for (final p in pages) {
      final tpl = p.templateId.replaceFirst('vocab.', '');
      final ex = p.hasExamples
          ? '${_r(p.exampleJaOk, 4)} ${_r(p.exampleKoOk, 4)}'
          : '   -    -';
      b.writeln(
        '${_r(p.page, 4)} ${tpl.padRight(5)}${_r(p.size, 3)} ${_r(p.found, 5)} '
        '${[for (final f in scoredFields) _r(p.fields[f] ?? 0, 4)].join(' ')} '
        '${_r(p.rowsOk, 4)} $ex ${p.metaOk ? 'ok' : p.meta}',
      );
    }
    b.writeln();
    b.writeln(
      'TOTAL  ${[for (final MapEntry(:key, :value) in totals.entries) '$key=${value.ok}/${value.of}'].join('  ')}',
    );
    b.writeln(
      'core fields wrong but NOT flagged (silent errors): $silentErrors',
    );
    b.write(
      'core fields wrong and flagged for review: $flaggedWrong;  flagged but actually correct: $flaggedOk',
    );
    return b.toString();
  }
}

String _r(Object v, int width) => '$v'.padLeft(width);

final RegExp _spaces = RegExp(r'\s+');
String _normMeaning(String s) =>
    nfkc(s).replaceAll(_spaces, '').replaceAll('，', ',');
double _similarity(String a, String b) => sequenceRatio(nfkc(a), nfkc(b));

Future<CaptureScore> scoreCapture({
  required GroundTruth truth,
  required Future<OcrScan> Function(String fixture) loadScan,
  required CapturePipeline pipeline,
}) async {
  final keys = [...scoredFields, 'ex_ja', 'ex_ko', 'row', 'found'];
  final ok = {for (final k in keys) k: 0};
  final of = {for (final k in keys) k: 0};
  var silent = 0, flaggedWrong = 0, flaggedOk = 0;
  final pages = <PageScore>[];

  for (final pg in truth.pages) {
    final draft = await pipeline.fromScan(await loadScan(pg.fixture));
    // Later entries with the same number win, as in the reference dict.
    final byNo = <String?, CapturedEntry>{
      for (final e in draft.entries) e.no: e,
    };
    final perField = {for (final f in scoredFields) f: 0};
    var found = 0, rowsOk = 0, exJa = 0, exKo = 0;
    final mistakes = <String>[];

    for (final g in pg.entries) {
      of['found'] = of['found']! + 1;
      of['row'] = of['row']! + 1;
      final e = byNo[g.no];
      if (e == null) {
        mistakes.add('MISS ${g.no} ${g.headword}');
        continue;
      }
      found++;
      ok['found'] = ok['found']! + 1;
      final checks = {
        'headword': e.headword == g.headword,
        'readings': listEquals(e.readings, g.readings),
        'pos': e.pos?.badge == g.pos,
        'meaning': _normMeaning(e.meaning) == _normMeaning(g.meaning),
        'important': e.important == g.important,
      };
      for (final f in scoredFields) {
        of[f] = of[f]! + 1;
        if (checks[f]!) {
          ok[f] = ok[f]! + 1;
          perField[f] = perField[f]! + 1;
        }
      }
      final rowOk = checks.values.every((v) => v);
      final gex = g.example;
      if (gex != null) {
        final got = e.example;
        final jaOk =
            got != null && _similarity(got.ja, gex.ja) >= exampleThreshold;
        final koOk =
            got != null && _similarity(got.ko, gex.ko) >= exampleThreshold;
        of['ex_ja'] = of['ex_ja']! + 1;
        of['ex_ko'] = of['ex_ko']! + 1;
        if (jaOk) {
          ok['ex_ja'] = ok['ex_ja']! + 1;
          exJa++;
        }
        if (koOk) {
          ok['ex_ko'] = ok['ex_ko']! + 1;
          exKo++;
        }
      }
      if (rowOk) {
        ok['row'] = ok['row']! + 1;
        rowsOk++;
      }
      final coreOk =
          checks['headword']! && checks['readings']! && checks['meaning']!;
      if (!coreOk && !e.isFlagged) silent++;
      if (!coreOk && e.isFlagged) flaggedWrong++;
      if (coreOk && e.isFlagged) flaggedOk++;
      if (!rowOk || e.issues.isNotEmpty) {
        final bad = [
          for (final f in scoredFields)
            if (!checks[f]!) f,
        ];
        mistakes.add(
          '${g.no} bad=$bad issues=${e.issues.map((i) => i.code).toList()} '
          'got=${e.headword}|${e.readings.join('/')}|${e.pos?.badge}|${e.meaning}|${e.important ? '★' : ''}',
        );
      }
    }

    final metaOk =
        draft.meta == PageMeta(day: pg.day, title: pg.title, page: pg.page);
    pages.add(
      PageScore(
        page: pg.page,
        templateId: draft.templateId,
        size: pg.entries.length,
        found: found,
        fields: Map.unmodifiable(perField),
        rowsOk: rowsOk,
        exampleJaOk: exJa,
        exampleKoOk: exKo,
        hasExamples: pg.entries.any((e) => e.example != null),
        meta: draft.meta,
        metaOk: metaOk,
        mistakes: List.unmodifiable(mistakes),
      ),
    );
  }

  return CaptureScore(
    pages: List.unmodifiable(pages),
    totals: Map.unmodifiable({
      for (final k in keys) k: (ok: ok[k]!, of: of[k]!),
    }),
    silentErrors: silent,
    flaggedWrong: flaggedWrong,
    flaggedOk: flaggedOk,
  );
}
