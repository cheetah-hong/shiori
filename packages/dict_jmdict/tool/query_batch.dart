// Runs dict_jmdict calls in bulk for tools/dict/eval_dict.py.
//
//   dart run tool/query_batch.dart --db PATH < queries.json > results.json
//
// Input: a JSON list of queries, each one of
//   {"op": "check",   "headword": "...", "reading": "..."|null}
//   {"op": "suggest", "text": "...",     "reading": "..."|null, "limit": 5,
//    "prefer": ["noun", ...] (WordClass names) | "prefer_pos": ["v5k", ...]}
// Output: {"info": {...meta...}, "micros": {"check": n, ...},
//          "results": [...]} with one result per query, in order.
import 'dart:convert';
import 'dart:io';

import 'package:dict_jmdict/dict_jmdict.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

Future<void> main(List<String> args) async {
  final at = args.indexOf('--db');
  if (at < 0 || at + 1 >= args.length) {
    stderr.writeln(
      'usage: dart run tool/query_batch.dart --db PATH < queries.json',
    );
    exitCode = 64;
    return;
  }
  final JmdictDictionary dict;
  try {
    dict = JmdictDictionary.open(args[at + 1]);
  } on JmdictFormatException catch (e) {
    stderr.writeln('cannot use ${args[at + 1]}: ${e.message}');
    exitCode = 66;
    return;
  } on SqliteException catch (e) {
    stderr.writeln('cannot open ${args[at + 1]}: ${e.message}');
    exitCode = 66;
    return;
  }
  try {
    final input = await stdin.transform(utf8.decoder).join();
    final decoded = jsonDecode(input);
    if (decoded is! List<Object?>) {
      throw const FormatException('expected a JSON list of queries');
    }
    final micros = <String, int>{};
    final counts = <String, int>{};
    final results = <Object?>[];
    for (final item in decoded) {
      if (item is! Map<String, Object?>) {
        throw const FormatException('each query must be a JSON object');
      }
      final op = item['op'] as String? ?? '';
      final watch = Stopwatch()..start();
      results.add(_run(dict, op, item));
      micros[op] = (micros[op] ?? 0) + watch.elapsedMicroseconds;
      counts[op] = (counts[op] ?? 0) + 1;
    }
    stdout.write(
      jsonEncode({
        'info': dict.info.values,
        'micros': micros,
        'counts': counts,
        'results': results,
      }),
    );
  } on FormatException catch (e) {
    stderr.writeln('bad query JSON: ${e.message}');
    exitCode = 65;
  } on TypeError catch (e) {
    stderr.writeln('bad query field type: $e');
    exitCode = 65;
  } on ArgumentError catch (e) {
    stderr.writeln('bad query value: ${e.message}');
    exitCode = 65;
  } finally {
    dict.close();
  }
}

Map<String, Object?> _run(
  JmdictDictionary dict,
  String op,
  Map<String, Object?> q,
) {
  final reading = q['reading'] as String?;
  switch (op) {
    case 'check':
      final c = dict.checkPair(q['headword'] as String? ?? '', reading);
      return {
        'match': c.match.name,
        'form': c.dictionaryForm,
        'parts': c.parts,
      };
    case 'suggest':
      final found = dict.suggestHeadword(
        q['text'] as String? ?? '',
        reading,
        limit: q['limit'] as int? ?? 5,
        prefer: _prefer(q),
      );
      return {
        'suggestions': [
          for (final s in found)
            {
              'headword': s.headword,
              'edits': s.edits.length,
              'reason': s.candidate.rankReason,
            },
        ],
      };
    default:
      throw FormatException('unknown op "$op"');
  }
}

/// Word classes from WordClass names, or from JMdict POS codes.
Set<WordClass> _prefer(Map<String, Object?> q) {
  final names = (q['prefer'] as List<Object?>? ?? const []).cast<String>();
  final pos = (q['prefer_pos'] as List<Object?>? ?? const []).cast<String>();
  return {
    for (final n in names) WordClass.values.byName(n),
    ...wordClassesOf(pos),
  };
}
