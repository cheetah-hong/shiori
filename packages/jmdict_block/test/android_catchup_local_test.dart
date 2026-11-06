// A4, A5, D4-D6 and extra-high (local only, real dictionaries): the capture
// as the app makes it (every page read by the word extractor) on the
// recorded word-list pages as both channels read them, on the scanner app's
// pages next to the photos they were made from, and no extra word at high
// confidence on any recorded set. Skipped without the dictionary files
// (SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB, SQLite; else the app's gzip
// assets next to $SHIORI_PRIVATE_DIR), and the recorded sets without
// $SHIORI_PRIVATE_DIR/textbook. Prints numbers only.
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
  const _Set(this.name, this.dir, this.truth);

  final String name;
  final String dir;
  final String truth;

  bool get exists => File(truth).existsSync() && Directory(dir).existsSync();

  ExtractTruth get answers => ExtractTruth.fromJson(
    (jsonDecode(File(truth).readAsStringSync()) as Map).cast<String, Object?>(),
  );

  /// The answer pages whose passes are in [dir].
  Iterable<ExtractTruthPage> get pages => answers.pages.where(
    (p) => File('$dir/${p.fixture}.ja.json').existsSync(),
  );

  Future<OcrScan> load(String fixture) => FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  ).recognize(PageImage(fixture));
}

String get _vocabTruth => '$_textbook/vocab_n5n3/general/ground_truth.json';
String get _curledTruth =>
    '$_textbook/device-iphone13mini/general/ground_truth.json';
String get _otherTruth => '$_textbook/other-books/ground_truth.json';
String get _pairs => '$_textbook/scan-pairs';

_Set get _mlKit => _Set(
  'word-list pages, ML Kit pieces',
  '$_textbook/ocr-android/fixtures_segment',
  _vocabTruth,
);
_Set get _vision =>
    _Set('word-list pages, Vision', '$_textbook/vocab_n5n3', _vocabTruth);
_Set get _curled => _Set(
  'curled phone page',
  '$_textbook/device-iphone13mini/fixtures',
  _curledTruth,
);
_Set get _other =>
    _Set('other textbook', '$_textbook/other-books/fixtures', _otherTruth);
_Set get _curledPhoto =>
    _Set('curled page, photo', '$_pairs/fx_raw', _curledTruth);
_Set get _curledScan =>
    _Set('curled page, scanner app', '$_pairs/fx_vflat', _curledTruth);
_Set get _examplesPhoto =>
    _Set('example pages, photo', '$_pairs/fx_raw_vb', '$_pairs/gt_vb.json');
_Set get _examplesScan => _Set(
  'example pages, scanner app',
  '$_pairs/fx_vflat_vb',
  '$_pairs/gt_vb.json',
);
_Set get _otherPhoto =>
    _Set('other textbook, photo', '$_pairs/fx_raw_ob', _otherTruth);
_Set get _otherScan =>
    _Set('other textbook, scanner app', '$_pairs/fx_vflat_ob', _otherTruth);

int _meaningsWrong(ExtractScore s) =>
    s.pages.fold(0, (n, p) => n + p.meanings.of - p.meanings.ok);
int _meaningsOk(ExtractScore s) => s.pages.fold(0, (n, p) => n + p.meanings.ok);
int _sentenceWords(ExtractScore s) =>
    s.pages.fold(0, (n, p) => n + p.sentenceWords.ok);

void main() {
  final temp = Directory.systemTemp.createTempSync('android_catchup_');
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
  final noDictionary = jmdictPath == null || glossaryPath == null
      ? 'dictionary files not found (set SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB)'
      : null;
  final sets = [
    _mlKit,
    _vision,
    _curled,
    _other,
    _curledPhoto,
    _curledScan,
    _examplesPhoto,
    _examplesScan,
    _otherPhoto,
    _otherScan,
  ];
  final noPages = sets.every((s) => s.exists)
      ? null
      : 'recorded pages not found under $_textbook (local only)';
  final skip = noDictionary ?? noPages;

  JmdictDictionary? jmdict;
  KrdictGlossary? glossary;
  late GeneralExtractor general;

  setUpAll(() {
    if (noDictionary != null) return;
    jmdict = JmdictDictionary.open(jmdictPath!);
    glossary = KrdictGlossary.open(glossaryPath!);
    general = GeneralExtractor(
      lexicon: JmdictLexiconAdapter(jmdict!),
      koreanGlossary: glossary,
    );
  });
  tearDownAll(() {
    glossary?.close();
    jmdict?.close();
    temp.deleteSync(recursive: true);
  });

  Future<ExtractScore> alone(_Set set) async => ExtractScore([
    for (final page in set.pages)
      scoreExtractPage(page, [
        for (final w in (await general.extract(
          await set.load(page.fixture),
        )).words)
          ScoredWord.fromExtracted(w),
      ]),
  ]);

  /// The review drafts the app makes of [set]'s pages.
  Future<ExtractScore> captured(_Set set) async => ExtractScore([
    for (final page in set.pages)
      scoreExtractPage(page, [
        for (final e in (await pageDraft(
          general,
          await set.load(page.fixture),
        )).entries)
          ScoredWord.fromCaptured(e),
      ]),
  ]);

  void show(String name, ExtractScore s) => print(
    // Printed for the score table (numbers only).
    '$name: found ${s.found}/${s.vocab} reading ${s.readingsOk} meaning '
    '${_meaningsOk(s)}/${s.pages.fold(0, (n, p) => n + p.meanings.of)} '
    'sentence ${_sentenceWords(s)} extras ${s.extras} duplicates '
    '${s.duplicates} high ${s.high} highWrong ${s.highWrong} extraHigh '
    '${s.extraHigh}',
  );

  test('A4 the word-list pages as ML Kit reads them, general extractor '
      'alone: found 58 or more of 59, every reading right, 1 or fewer '
      'meanings wrong, 2 or fewer extras, 33 or more high (D5), nothing '
      'wrong at high', () async {
    final s = await captured(_mlKit);
    show('ML Kit pieces, as the app reads them', s);
    expect(s.vocab, 59);
    expect(s.found, greaterThanOrEqualTo(58));
    expect(s.readingsOk, s.found);
    expect(_meaningsWrong(s), lessThanOrEqualTo(1));
    expect(s.extras, lessThanOrEqualTo(2));
    expect(s.high, greaterThanOrEqualTo(33));
    expect(s.highWrong, 0);
    expect(s.extraHigh, 0);
  }, skip: skip);

  test('D4 the word-list pages as Vision reads them: all 59 found and read '
      'right, 1 or fewer meanings wrong, no extra, 17 or more high', () async {
    final s = await captured(_vision);
    show('Vision, as the app reads them', s);
    expect(s.vocab, 59);
    expect(s.found, 59);
    expect(s.readingsOk, 59);
    expect(_meaningsWrong(s), lessThanOrEqualTo(1));
    expect(s.extras, 0);
    expect(s.high, greaterThanOrEqualTo(17));
    expect(s.highWrong, 0);
    expect(s.extraHigh, 0);
  }, skip: skip);

  test('A5 the curled page from the scanner app: 14 or more of 15, '
      'no meaning wrong, 1 or fewer extras', () async {
    final s = await captured(_curledScan);
    show('curled page, scanner app', s);
    expect(s.vocab, 15);
    expect(s.found, greaterThanOrEqualTo(14));
    expect(s.readingsOk, s.found);
    expect(_meaningsWrong(s), 0);
    expect(s.extras, lessThanOrEqualTo(1));
    expect(s.highWrong, 0);
  }, skip: skip);

  test('A5 the photos the scans were made from do not get worse', () async {
    final curled = await captured(_curledPhoto);
    show('curled page, photo', curled);
    expect(curled.found, 15);
    expect(curled.readingsOk, 15);
    expect(_meaningsWrong(curled), 0);
    expect(curled.extras, 0);

    for (final set in [_examplesPhoto, _examplesScan]) {
      final s = await captured(set);
      show(set.name, s);
      expect(s.found, s.vocab, reason: set.name);
      expect(s.readingsOk, s.vocab, reason: set.name);
      expect(_meaningsWrong(s), 0, reason: set.name);
      expect(s.extras, 0, reason: set.name);
      // D6: the example pages went to the row template before; high >= 4.
      expect(s.high, greaterThanOrEqualTo(4), reason: set.name);
    }

    final photo = await captured(_otherPhoto);
    show('other textbook, photo', photo);
    expect(photo.found, 15);
    expect(_meaningsOk(photo), greaterThanOrEqualTo(11));
    expect(_sentenceWords(photo), greaterThanOrEqualTo(30));
    expect(photo.extras, lessThanOrEqualTo(6));

    final scan = await captured(_otherScan);
    show('other textbook, scanner app', scan);
    expect(scan.found, greaterThanOrEqualTo(14));
    expect(_meaningsOk(scan), greaterThanOrEqualTo(9));
    expect(_sentenceWords(scan), greaterThanOrEqualTo(30));
    expect(scan.extras, lessThanOrEqualTo(6));
  }, skip: skip);

  test('no recorded set has an extra word at high confidence, nor a wrong '
      'one, from the extractor or on the review draft', () async {
    for (final set in sets) {
      for (final (how, s) in [
        ('extractor', await alone(set)),
        ('review draft', await captured(set)),
      ]) {
        show('${set.name}, $how', s);
        expect(s.extraHigh, 0, reason: '${set.name}, $how');
        expect(s.highWrong, 0, reason: '${set.name}, $how');
      }
    }
  }, skip: skip);
}
