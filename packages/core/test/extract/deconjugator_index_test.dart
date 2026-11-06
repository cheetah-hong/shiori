// A7: the deconjugation rules indexed by the ending they take off give the
// same candidates, in the same order, as trying every rule on every form;
// and a sentence page stays fast.
import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/data/deconjugation_rules.dart';
import 'package:shiori_core/src/extract/deconjugator.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

/// Every substring of at most 12 characters of every Japanese line of the
/// synthetic general pages, and the unit tests' conjugated words.
Set<String> _surfaces() {
  final out = <String>{
    '食べました',
    '書いて',
    '行った',
    '来なかった',
    'した',
    '静かな',
    '高くない',
    '読まれた',
    '丈夫だ',
    'しなければならない',
    '行かせられなかった',
  };
  for (final f in Directory(generalDir).listSync()) {
    if (!f.path.endsWith('.ja.json')) continue;
    final json = jsonDecode(File(f.path).readAsStringSync()) as Map;
    for (final l in (json['lines'] as List).cast<Map<String, Object?>>()) {
      final runes = (l['t']! as String).runes.toList();
      for (var i = 0; i < runes.length; i++) {
        for (var j = i + 1; j <= runes.length && j - i <= 12; j++) {
          out.add(String.fromCharCodes(runes.sublist(i, j)));
        }
      }
    }
  }
  return out;
}

String _show(List<Deinflection> ds) =>
    [for (final d in ds) '${d.base}|${d.tag}|${d.steps.join('>')}'].join(' ; ');

void main() {
  test('indexed rules give every candidate the full scan gives, in its '
      'order', () {
    final indexed = Deconjugator(deconjugationRulesJson);
    final full = Deconjugator(deconjugationRulesJson, indexed: false);
    final surfaces = _surfaces();
    expect(surfaces.length, greaterThan(3000));
    for (final s in surfaces) {
      expect(
        _show(indexed.deconjugate(s)),
        _show(full.deconjugate(s)),
        reason: s,
      );
    }
  });

  test('the bundled rules are indexed', () {
    expect(Deconjugator.standard.indexed, isTrue);
  });

  test('a sentence page takes at most 300 ms once warm', () async {
    final extractor = GeneralExtractor(
      lexicon: generalLexicon(),
      koreanGlossary: generalGlossary(),
    );
    final page = await loadGeneralScan('g02');
    await extractor.extract(page); // warm-up: JIT and first lookups
    final watch = Stopwatch()..start();
    await extractor.extract(page);
    watch.stop();
    print('g02 warm: ${watch.elapsedMilliseconds} ms');
    expect(watch.elapsedMilliseconds, lessThanOrEqualTo(300));
  });
}
