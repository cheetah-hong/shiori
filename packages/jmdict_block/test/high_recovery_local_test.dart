// R3, R4, R5, R8 on recorded pages and the synthetic sets with the real
// dictionaries (local only): a pair held back only by a fragment read at
// the engine's lowest confidence is high when the word's other pair backs
// it. Every set keeps its lower bound of high entries with no wrong or extra
// entry at high; the values (headwords, readings, meanings, examples, their
// order) are those recorded before the rule; with every line read at the
// lowest confidence nothing wrong or extra is high either. Prints numbers
// only. Skipped without the recorded pages ($SHIORI_PRIVATE_DIR/textbook)
// or the dictionary files (SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB,
// SQLite; else the app's gzip assets next to the private folder).
//
// The recorded values are written once, before the rule, with
// SHIORI_WRITE_VALUES=1 (to $SHIORI_PRIVATE_DIR/textbook/snapshots).
import 'dart:convert';
import 'dart:io';

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

File get _valuesFile =>
    File('$_textbook/snapshots/extract-values-before-faint-rule.json');

/// The SQLite file of [envName], else [asset] (gzip) unpacked to [temp].
String? _database(String envName, String asset, Directory temp) {
  final fromEnv = Platform.environment[envName];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  final gz = File(
    Directory(
      _privateDir(),
    ).uri.resolve('../app/assets/dict/$asset').toFilePath(),
  );
  if (!gz.existsSync()) return null;
  final out = File('${temp.path}/${asset.replaceAll('.gz', '')}')
    ..writeAsBytesSync(gzip.decode(gz.readAsBytesSync()));
  return out.path;
}

final class _Set {
  const _Set(
    this.name,
    this.dir,
    this.truth,
    this.minHigh,
    this.values, {
    this.recorded = true,
    this.read = _asRead,
  });

  final String name;
  final String dir;
  final String truth;

  /// Lower bound of high entries.
  final int minHigh;

  /// found, readings right, meanings right, extras.
  final List<int> values;

  /// Its values are compared with those recorded before the rule.
  final bool recorded;

  /// How the scan reaches the extractor (a variant of the recorded passes).
  final OcrScan Function(OcrScan) read;

  bool get exists => File(truth).existsSync() && Directory(dir).existsSync();

  ExtractTruth get answers => ExtractTruth.fromJson(
    (jsonDecode(File(truth).readAsStringSync()) as Map).cast<String, Object?>(),
  );

  Future<OcrScan> load(String fixture) async => read(
    await FixtureTextRecognizer(
      (name) => File('$dir/$name').readAsString(),
    ).recognize(PageImage(fixture)),
  );
}

OcrScan _asRead(OcrScan scan) => scan;

/// The curled page as a device that reads its blank reading cells (a flat
/// dash) as the kanji 一 at 0.5 returns it.
OcrScan _dashAsKanji(OcrScan scan) => OcrScan(
  japanese: OcrPage(
    lines: [
      for (final l in scan.japanese.lines)
        if (l.text.trim() == 'ー' && l.confidence <= 0.3 + 1e-6)
          OcrLine(
            text: '一',
            x: l.x,
            y: l.y,
            width: l.width,
            height: l.height,
            confidence: 0.5,
          )
        else
          l,
    ],
    engine: scan.japanese.engine,
    languages: scan.japanese.languages,
  ),
  korean: scan.korean,
);

/// [scan] with every line of the passes chosen read at the lowest
/// confidence, as the device channel passes it on.
OcrScan _lowered(OcrScan scan, {required bool ja, required bool ko}) {
  OcrPage low(OcrPage p, bool on) => !on
      ? p
      : OcrPage(
          lines: [
            for (final l in p.lines)
              OcrLine(
                text: l.text,
                x: l.x,
                y: l.y,
                width: l.width,
                height: l.height,
                confidence: 0.30000001192092896,
              ),
          ],
          engine: p.engine,
          languages: p.languages,
        );
  return OcrScan(
    japanese: low(scan.japanese, ja),
    korean: low(scan.korean, ko),
    turned: scan.turned,
  );
}

String get _vocabTruth => '$_textbook/vocab_n5n3/general/ground_truth.json';
String get _curledTruth =>
    '$_textbook/device-iphone13mini/general/ground_truth.json';
String get _otherTruth => '$_textbook/other-books/ground_truth.json';
String get _pairs => '$_textbook/scan-pairs';
const String _synthetic = '../core/test/fixtures';

List<_Set> get _sets => [
  _Set('word-list pages, Vision', '$_textbook/vocab_n5n3', _vocabTruth, 36, [
    59,
    59,
    58,
    0,
  ]),
  _Set(
    'word-list pages, ML Kit pieces',
    '$_textbook/ocr-android/fixtures_segment',
    _vocabTruth,
    37,
    [58, 58, 57, 1],
  ),
  _Set(
    'curled phone page',
    '$_textbook/device-iphone13mini/fixtures',
    _curledTruth,
    7,
    [15, 15, 15, 0],
  ),
  _Set(
    'curled phone page, dash read as 一',
    '$_textbook/device-iphone13mini/fixtures',
    _curledTruth,
    7,
    [15, 15, 15, 0],
    read: _dashAsKanji,
  ),
  _Set('other textbook', '$_textbook/other-books/fixtures', _otherTruth, 8, [
    15,
    15,
    11,
    4,
  ]),
  _Set('curled page, photo', '$_pairs/fx_raw', _curledTruth, 6, [
    15,
    15,
    15,
    0,
  ]),
  _Set('curled page, scanner app', '$_pairs/fx_vflat', _curledTruth, 8, [
    14,
    14,
    14,
    1,
  ]),
  _Set('example pages, photo', '$_pairs/fx_raw_vb', '$_pairs/gt_vb.json', 5, [
    12,
    12,
    12,
    0,
  ]),
  _Set(
    'example pages, scanner app',
    '$_pairs/fx_vflat_vb',
    '$_pairs/gt_vb.json',
    6,
    [12, 12, 12, 0],
  ),
  _Set('other textbook, photo', '$_pairs/fx_raw_ob', _otherTruth, 8, [
    15,
    15,
    11,
    6,
  ]),
  // The checkbox column no longer passes for a lost headword here: a kana
  // headword stays as printed (found 14 -> 15, extras 6 -> 5).
  _Set(
    'other textbook, scanner app',
    '$_pairs/fx_vflat_ob',
    _otherTruth,
    6,
    [15, 15, 10, 5],
    recorded: false,
  ),
  const _Set(
    'synthetic word-list pages',
    '$_synthetic/synthetic',
    '$_synthetic/synthetic/ground_truth.json',
    24,
    [33, 33, 32, 2],
  ),
  const _Set(
    'synthetic word-list pages, ML Kit',
    '$_synthetic/synthetic_mlkit',
    '$_synthetic/synthetic_mlkit/ground_truth.json',
    13,
    [17, 17, 16, 1],
  ),
  const _Set(
    'synthetic general pages',
    '$_synthetic/synthetic_general',
    '$_synthetic/synthetic_general/ground_truth.json',
    44,
    [70, 70, 68, 0],
  ),
  const _Set(
    'synthetic Android pages',
    '$_synthetic/synthetic_general',
    '$_synthetic/synthetic_general/ground_truth_android.json',
    20,
    [29, 29, 21, 3],
  ),
  const _Set(
    'synthetic trap pages',
    '$_synthetic/synthetic_general',
    '$_synthetic/synthetic_general/ground_truth_traps.json',
    2,
    [6, 6, 6, 0],
  ),
];

/// The values of a draft's entries, in order, without confidence or
/// evidence.
List<List<String>> _values(CaptureDraft draft) => [
  for (final e in draft.entries)
    [
      e.headword,
      e.readings.join('/'),
      e.meaning,
      e.example?.ja ?? '',
      e.example?.ko ?? '',
    ],
];

void main() {
  final temp = Directory.systemTemp.createTempSync('high_recovery_');
  final jmdictPath = _database(
    'SHIORI_JMDICT_DB',
    'jmdict-full-lean.sqlite.gz',
    temp,
  );
  final glossaryPath = _database(
    'SHIORI_KO_GLOSSARY_DB',
    'ko-glossary.sqlite.gz',
    temp,
  );
  final skip = !_sets.every((s) => s.exists)
      ? 'recorded pages not found under $_textbook (local only)'
      : jmdictPath == null || glossaryPath == null
      ? 'dictionary files not found (set SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB)'
      : null;

  JmdictDictionary? jmdict;
  KrdictGlossary? glossary;
  late GeneralExtractor extractor;

  setUpAll(() {
    if (skip != null) return;
    jmdict = JmdictDictionary.open(jmdictPath!);
    glossary = KrdictGlossary.open(glossaryPath!);
    extractor = GeneralExtractor(
      lexicon: JmdictLexiconAdapter(jmdict!),
      koreanGlossary: glossary,
    );
  });
  tearDownAll(() {
    glossary?.close();
    jmdict?.close();
    temp.deleteSync(recursive: true);
  });

  Future<(ExtractScore, Map<String, List<List<String>>>)> run(
    _Set set,
    OcrScan Function(OcrScan) variant,
  ) async {
    final pages = <PageExtractScore>[];
    final values = <String, List<List<String>>>{};
    for (final page in set.answers.pages) {
      final draft = await pageDraft(
        extractor,
        variant(await set.load(page.fixture)),
      );
      values[page.fixture] = _values(draft);
      pages.add(
        scoreExtractPage(page, [
          for (final e in draft.entries) ScoredWord.fromCaptured(e),
        ]),
      );
    }
    return (ExtractScore(pages), values);
  }

  test('R3 R4 R5 every set: high at or above its lower bound, nothing wrong '
      'or extra at high, values hold', () async {
    final recorded = <String, Object?>{};
    final before = _valuesFile.existsSync()
        ? (jsonDecode(_valuesFile.readAsStringSync()) as Map)
              .cast<String, Object?>()
        : null;
    final write = Platform.environment['SHIORI_WRITE_VALUES'] == '1';
    for (final set in _sets) {
      final (s, values) = await run(set, _asRead);
      // Printed for the score table (numbers only).
      print(
        '${set.name}: high ${s.high}, high but wrong ${s.highWrong}, '
        'extra at high ${s.extraHigh}, found ${s.found}/${s.vocab} '
        'reading ${s.readingsOk} meaning ${s.meanings.ok}/${s.meanings.of} '
        'extras ${s.extras}',
      );
      recorded[set.name] = values;
      expect(s.highWrong, 0, reason: set.name);
      expect(s.extraHigh, 0, reason: set.name);
      if (write && !set.recorded) continue;
      expect(
        [s.found, s.readingsOk, s.meanings.ok, s.extras],
        set.values,
        reason: set.name,
      );
      if (write) continue;
      expect(s.high, greaterThanOrEqualTo(set.minHigh), reason: set.name);
      if (!set.recorded) continue;
      expect(before, isNotNull, reason: 'no values recorded before the rule');
      expect(
        jsonEncode(values),
        jsonEncode(before![set.name]),
        reason: '${set.name}: values changed',
      );
    }
    if (write) {
      _valuesFile
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(recorded));
    }
  }, skip: skip);

  for (final (passes, ja, ko) in [
    ('both passes', true, true),
    ('the Japanese pass', true, false),
    ('the Korean pass', false, true),
  ]) {
    test('R8 every line of $passes read at the lowest confidence: nothing '
        'wrong or extra at high', () async {
      for (final set in _sets) {
        final (s, _) = await run(set, (scan) => _lowered(scan, ja: ja, ko: ko));
        print('$passes, ${set.name}: high ${s.high}');
        expect(s.highWrong, 0, reason: set.name);
        expect(s.extraHigh, 0, reason: set.name);
      }
    }, skip: skip);
  }
}
