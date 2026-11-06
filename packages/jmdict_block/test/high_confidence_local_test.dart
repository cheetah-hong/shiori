// C8 on recorded pages with the real dictionaries (local only): the capture
// as the app makes it, with JMdict and the Korean glossary. No high entry is
// wrong; each set has at least as many high entries as its lower bound; the
// values hold (D4-D6: the word-list pages, which went to the row template
// before, as the word extractor reads them). Prints numbers only. Skipped without the
// recorded pages ($SHIORI_PRIVATE_DIR/textbook) or the dictionary files
// (SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB, SQLite; else the app's gzip
// assets next to the private folder).
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
  const _Set(this.name, this.dir, this.truth, this.minHigh, this.values);

  final String name;
  final String dir;
  final String truth;

  /// Lower bound of high entries (set from the measurement).
  final int minHigh;

  /// found, readings right, meanings right, extras.
  final List<int> values;

  bool get exists => File(truth).existsSync() && Directory(dir).existsSync();

  ExtractTruth get answers => ExtractTruth.fromJson(
    (jsonDecode(File(truth).readAsStringSync()) as Map).cast<String, Object?>(),
  );

  Future<OcrScan> load(String fixture) => FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  ).recognize(PageImage(fixture));
}

final _sets = [
  _Set(
    'recorded textbook pages',
    '$_textbook/vocab_n5n3',
    '$_textbook/vocab_n5n3/general/ground_truth.json',
    17,
    const [59, 59, 58, 0],
  ),
  _Set(
    'recorded textbook pages, ML Kit',
    '$_textbook/ocr-android/fixtures_segment',
    '$_textbook/vocab_n5n3/general/ground_truth.json',
    33,
    const [58, 58, 57, 1],
  ),
  _Set(
    'curled phone page',
    '$_textbook/device-iphone13mini/fixtures',
    '$_textbook/device-iphone13mini/general/ground_truth.json',
    4,
    const [15, 15, 15, 0],
  ),
  _Set(
    'other textbook',
    '$_textbook/other-books/fixtures',
    '$_textbook/other-books/ground_truth.json',
    6,
    const [15, 15, 11, 4],
  ),
];

void main() {
  final temp = Directory.systemTemp.createTempSync('high_confidence_');
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

  Future<ExtractScore> score(_Set set) async => ExtractScore([
    for (final page in set.answers.pages)
      scoreExtractPage(page, [
        for (final e in (await pageDraft(
          extractor,
          await set.load(page.fixture),
        )).entries)
          ScoredWord.fromCaptured(e),
      ]),
  ]);

  test('C8 every recorded set: high but wrong 0, high entries at or above '
      'the lower bound, values hold', () async {
    for (final set in _sets) {
      final s = await score(set);
      // Printed for the score table (numbers only).
      print(
        '${set.name}: high ${s.high}, high but wrong ${s.highWrong}, '
        'found ${s.found}/${s.vocab} reading ${s.readingsOk} '
        'meaning ${s.meanings.ok}/${s.meanings.of} extras ${s.extras}',
      );
      expect(s.highWrong, 0, reason: set.name);
      expect(s.high, greaterThanOrEqualTo(set.minHigh), reason: set.name);
      expect(
        [s.found, s.readingsOk, s.meanings.ok, s.extras],
        set.values,
        reason: set.name,
      );
    }
  }, skip: skip);
}
