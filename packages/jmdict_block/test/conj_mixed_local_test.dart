// C6 on recorded pages and the synthetic sets with the real dictionaries
// (local only): conjugated stems read back to their dictionary form, Latin
// debris taken out of a meaning, the class a sentence uses a word as and a
// page band's counter leave every set at its approved values (found,
// readings right, meanings right, extras), with nothing wrong or extra at
// high and high entries at or above the lower bound. The device page the
// change came from is checked against its judgement file (headwords left
// out, read once, meanings, the corrected mark, a filled meaning's first
// sense). Prints numbers only. Skipped without the recorded pages
// ($SHIORI_PRIVATE_DIR/textbook) or the dictionary files (SHIORI_JMDICT_DB
// and SHIORI_KO_GLOSSARY_DB, SQLite; else the app's gzip assets next to the
// private folder).
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

Map<String, Object?> _json(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

final class _Set {
  const _Set(this.name, this.dir, this.truth, this.minHigh, this.values);

  final String name;
  final String dir;
  final String truth;

  /// Lower bound of high entries (docs/verification.md 22).
  final int minHigh;

  /// found, readings right, meanings right, extras (approved for this
  /// change, docs/verification.md 26).
  final List<int> values;

  bool get exists => File(truth).existsSync() && Directory(dir).existsSync();

  ExtractTruth get answers => ExtractTruth.fromJson(_json(truth));

  Future<OcrScan> load(String fixture) => FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  ).recognize(PageImage(fixture));
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
  _Set('other textbook', '$_textbook/other-books/fixtures', _otherTruth, 8, [
    15,
    15,
    12,
    1,
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
    12,
    2,
  ]),
  _Set('other textbook, scanner app', '$_pairs/fx_vflat_ob', _otherTruth, 6, [
    15,
    15,
    10,
    1,
  ]),
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

String get _feedbackDir => '$_textbook/device-iphone13mini/feedback-1747';
String get _judgementFile => '$_feedbackDir/judgement.json';

void main() {
  final temp = Directory.systemTemp.createTempSync('conj_mixed_');
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
  final skip =
      !_sets.every((s) => s.exists) || !File(_judgementFile).existsSync()
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

  void expectScore(String name, ExtractScore s, int minHigh, List<int> want) {
    print(
      '$name: high ${s.high}, high but wrong ${s.highWrong}, '
      'extra at high ${s.extraHigh}, found ${s.found}/${s.vocab} '
      'reading ${s.readingsOk} meaning ${s.meanings.ok}/${s.meanings.of} '
      'extras ${s.extras}',
    );
    expect(s.highWrong, 0, reason: name);
    expect(s.extraHigh, 0, reason: name);
    expect(s.high, greaterThanOrEqualTo(minHigh), reason: name);
    expect(
      [s.found, s.readingsOk, s.meanings.ok, s.extras],
      want,
      reason: name,
    );
  }

  test('C6 every set at its approved values; nothing wrong or extra at '
      'high; high at or above the lower bound', () async {
    for (final set in _sets) {
      final pages = <PageExtractScore>[];
      for (final page in set.answers.pages) {
        final draft = await pageDraft(extractor, await set.load(page.fixture));
        pages.add(
          scoreExtractPage(page, [
            for (final e in draft.entries) ScoredWord.fromCaptured(e),
          ]),
        );
      }
      expectScore(set.name, ExtractScore(pages), set.minHigh, set.values);
    }
  }, skip: skip);

  test('C6 the device page: as its judgement file says', () async {
    final judged = _json(_judgementFile);
    final fixture = judged['fixture']! as String;
    final truth = ExtractTruth.fromJson(
      _json('$_textbook/${judged['truth']! as String}'),
    );
    final page = truth.pages.singleWhere(
      (p) => p.fixture == judged['truthPage'],
    );
    final draft = await pageDraft(
      extractor,
      await FixtureTextRecognizer(
        (name) => File('$_feedbackDir/$name').readAsString(),
      ).recognize(PageImage(fixture)),
    );
    final entries = draft.entries;
    expectScore(
      'device page',
      ExtractScore([
        scoreExtractPage(page, [
          for (final e in entries) ScoredWord.fromCaptured(e),
        ]),
      ]),
      judged['minHigh']! as int,
      (judged['values']! as List).cast<int>(),
    );
    final heads = [for (final e in entries) e.headword];
    for (final h in (judged['absent']! as List).cast<String>()) {
      expect(heads, isNot(contains(h)), reason: 'absent #${heads.length}');
    }
    for (final h in (judged['once']! as List).cast<String>()) {
      expect(heads.where((x) => x == h), hasLength(1), reason: 'once');
    }
    CapturedEntry of(String h) => entries.singleWhere((e) => e.headword == h);
    for (final MapEntry(:key, :value)
        in (judged['meanings']! as Map).cast<String, String>().entries) {
      expect(of(key).meaning, value, reason: 'meaning');
    }
    for (final h in (judged['corrected']! as List).cast<String>()) {
      expect(
        of(h).issues,
        contains(
          const EntryIssue.corrected(
            EntryField.meaning,
            note: latinDebrisRemovedNote,
          ),
        ),
        reason: 'corrected',
      );
    }
    for (final MapEntry(:key, :value)
        in (judged['firstMeaning']! as Map).cast<String, String>().entries) {
      final e = of(key);
      expect(
        e.evidence?.of(EntryField.meaning)?.source,
        FieldSource.dictionary,
        reason: 'filled',
      );
      expect(e.meaning, value, reason: 'first sense');
    }
  }, skip: skip);
}
