// X6 on the recorded pages with the real dictionaries and the real example
// sentences (local only): words the pages give no example get a Tatoeba
// sentence through their JMdict entry (at least 65 of the distinct words;
// the survey counted 73 of 82), and a word with a page example keeps it,
// byte for byte. Prints numbers only.
// Skipped without the recorded pages ($SHIORI_PRIVATE_DIR/textbook) or the
// files (SHIORI_JMDICT_DB, SHIORI_KO_GLOSSARY_DB, SHIORI_WIKT_GLOSSARY_DB,
// SHIORI_EXAMPLES_DB, SQLite; else the gzip assets of this checkout's app,
// else those next to the private folder).
import 'dart:convert';
import 'dart:io';

import 'package:example_block/example_block.dart';
import 'package:jmdict_block/jmdict_block.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

String _privateDir() {
  final fromEnv = Platform.environment['SHIORI_PRIVATE_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return Directory.current.uri.resolve('../../.private').toFilePath();
}

String get _textbook => '${_privateDir()}/textbook';

/// The SQLite file of [envName], else this checkout's [asset] (gzip), else
/// the one next to the private folder, unpacked to [temp].
String? _database(String envName, String asset, Directory temp) {
  final fromEnv = Platform.environment[envName];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  for (final gz in [
    File(
      Directory.current.uri.resolve('../../app/assets/dict/$asset').toFilePath(),
    ),
    File(
      Directory(
        _privateDir(),
      ).uri.resolve('../app/assets/dict/$asset').toFilePath(),
    ),
  ]) {
    if (!gz.existsSync()) continue;
    final out = File('${temp.path}/${asset.replaceAll('.gz', '')}')
      ..writeAsBytesSync(gzip.decode(gz.readAsBytesSync()));
    return out.path;
  }
  return null;
}

Map<String, Object?> _json(File f) =>
    (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();

String get _vocabTruth => '$_textbook/vocab_n5n3/general/ground_truth.json';
String get _curledTruth =>
    '$_textbook/device-iphone13mini/general/ground_truth.json';
String get _otherTruth => '$_textbook/other-books/ground_truth.json';
String get _pairs => '$_textbook/scan-pairs';

/// (pages folder, answers) of every recorded set.
List<(String, String)> get _sets => [
  ('$_textbook/vocab_n5n3', _vocabTruth),
  ('$_textbook/ocr-android/fixtures_segment', _vocabTruth),
  ('$_textbook/device-iphone13mini/fixtures', _curledTruth),
  ('$_textbook/other-books/fixtures', _otherTruth),
  ('$_pairs/fx_raw', _curledTruth),
  ('$_pairs/fx_vflat', _curledTruth),
  ('$_pairs/fx_raw_vb', '$_pairs/gt_vb.json'),
  ('$_pairs/fx_vflat_vb', '$_pairs/gt_vb.json'),
  ('$_pairs/fx_raw_ob', _otherTruth),
  ('$_pairs/fx_vflat_ob', _otherTruth),
];

const int _minFilled = 65;

Word _word(CapturedEntry e) => Word(
  id: 'local:${e.headword}',
  headword: e.headword,
  readings: e.readings,
  meaning: e.meaning,
  createdAt: DateTime.utc(2026, 11, 12),
  pos: e.pos,
  example: e.example,
);

void main() {
  final temp = Directory.systemTemp.createTempSync('example_fill_');
  final paths = {
    for (final (env, asset) in const [
      ('SHIORI_JMDICT_DB', 'jmdict-full-lean.sqlite.gz'),
      ('SHIORI_KO_GLOSSARY_DB', 'ko-glossary.sqlite.gz'),
      ('SHIORI_WIKT_GLOSSARY_DB', 'wikt-glossary.sqlite.gz'),
      ('SHIORI_EXAMPLES_DB', 'examples.sqlite.gz'),
    ])
      env: _database(env, asset, temp),
  };
  final skip =
      !_sets.every(
        (s) => File(s.$2).existsSync() && Directory(s.$1).existsSync(),
      )
      ? 'recorded pages not found under $_textbook (local only)'
      : paths.values.any((p) => p == null)
      ? 'files not found (set ${paths.keys.join(', ')})'
      : null;

  JmdictDictionary? jmdict;
  KrdictGlossary? glossary;
  KrdictGlossary? wikt;
  TatoebaExamples? examples;
  late JmdictLexiconAdapter lexicon;
  late GeneralExtractor extractor;

  setUpAll(() {
    if (skip != null) return;
    jmdict = JmdictDictionary.open(paths['SHIORI_JMDICT_DB']!);
    glossary = KrdictGlossary.open(paths['SHIORI_KO_GLOSSARY_DB']!);
    wikt = KrdictGlossary.open(paths['SHIORI_WIKT_GLOSSARY_DB']!);
    examples = TatoebaExamples.open(paths['SHIORI_EXAMPLES_DB']!);
    lexicon = JmdictLexiconAdapter(jmdict!);
    extractor = GeneralExtractor(
      lexicon: lexicon,
      koreanGlossary: glossary,
      meaningFallback: wikt,
    );
  });
  tearDownAll(() {
    examples?.close();
    wikt?.close();
    glossary?.close();
    jmdict?.close();
    temp.deleteSync(recursive: true);
  });

  test('X6 words without a page example get a sentence; page examples stay '
      'as they are', () async {
    final without = <String, CapturedEntry>{};
    var withPage = 0;
    for (final (dir, truth) in _sets) {
      final recognizer = FixtureTextRecognizer(
        (name) => File('$dir/$name').readAsString(),
      );
      for (final page in ExtractTruth.fromJson(_json(File(truth))).pages) {
        if (!File('$dir/${page.fixture}.ja.json').existsSync()) continue;
        final scan = await recognizer.recognize(PageImage(page.fixture));
        for (final e in (await pageDraft(extractor, scan)).entries) {
          final printed = e.example;
          if (printed == null) {
            without.putIfAbsent(e.headword, () => e);
            continue;
          }
          withPage++;
          final shown = await cardExampleOf(
            _word(e),
            lexicon: lexicon,
            examples: examples!,
          );
          expect(shown?.origin, ExampleOrigin.page, reason: e.headword);
          expect(utf8.encode(shown!.ja), utf8.encode(printed.ja));
          expect(
            utf8.encode(shown.ko ?? ''),
            utf8.encode(printed.ko),
            reason: e.headword,
          );
        }
      }
    }
    var filled = 0, korean = 0, english = 0, none = 0;
    for (final e in without.values) {
      final shown = await cardExampleOf(
        _word(e),
        lexicon: lexicon,
        examples: examples!,
      );
      if (shown == null) continue;
      expect(shown.origin, ExampleOrigin.tatoeba);
      filled++;
      if (shown.ko != null) {
        korean++;
      } else if (shown.en != null) {
        english++;
      } else {
        none++;
      }
    }
    print(
      'X6 recorded sets: page examples kept $withPage; words without one '
      '${without.length}, filled $filled (Korean $korean, English $english, '
      'none $none)',
    );
    expect(withPage, greaterThan(0));
    expect(filled, greaterThanOrEqualTo(_minFilled));
  }, skip: skip);
}
