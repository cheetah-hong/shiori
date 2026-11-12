// P5 on recorded pages and the synthetic sets with the real dictionaries, as
// the app builds the extractor (local only): bracketed readings with an
// ending or an honorific, checkboxes glued to the words of a page of few
// rows, a bracketed line at the engine's lowest confidence and a mark set
// apart after a meaning leave every set at its approved values (found,
// readings right, meanings right, extras), nothing wrong or extra at high,
// high at or above the lower bound. The real-use pages (a word-list page and
// its last two rows cut out) reach the values of their answer file. On every
// recorded page the review drafts keep the values recorded before the
// change but the entries the change was approved to alter (local files).
// Every line read at the lowest confidence: nothing wrong or extra at high.
// Prints numbers only. Skipped without the recorded pages
// ($SHIORI_PRIVATE_DIR/textbook) or the dictionary files (SHIORI_JMDICT_DB,
// SHIORI_KO_GLOSSARY_DB and SHIORI_WIKT_GLOSSARY_DB, SQLite; else the app's
// gzip assets next to the private folder). The values before the change are
// written once with SHIORI_WRITE_VALUES=1.
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
    File('$_textbook/snapshots/extract-values-before-paren-tail.json');

File get _changesFile => File('$_textbook/snapshots/paren-tail-changes.json');

String get _realUse => '$_textbook/device-iphone13mini/realuse-1112';

/// found, readings right, meanings right, extras, lower bound of high.
File get _realUseExpected => File('$_realUse/expected.json');

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

Map<String, Object?> _json(File f) =>
    (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();

final class _Set {
  const _Set(
    this.name,
    this.dir,
    this.truth,
    this.minHigh,
    this.values, {
    this.truthPage,
  });

  final String name;
  final String dir;
  final String truth;

  /// Lower bound of high entries (docs/verification.md 22, 35).
  final int minHigh;

  /// found, readings right, meanings right, extras (docs/verification.md 35).
  final List<int> values;

  /// A device page scored with another page's answers: that page.
  final String? truthPage;

  bool get exists => File(truth).existsSync() && Directory(dir).existsSync();

  /// (fixture, the answers it is scored with).
  List<(String, ExtractTruthPage)> get pages {
    final answers = ExtractTruth.fromJson(_json(File(truth)));
    final page = truthPage;
    if (page == null) return [for (final p in answers.pages) (p.fixture, p)];
    final fixture = Directory(dir)
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .firstWhere((n) => n.endsWith('.ja.json'))
        .replaceAll('.ja.json', '');
    return [(fixture, answers.pages.singleWhere((p) => p.fixture == page))];
  }

  Future<OcrScan> load(String fixture) => _load(dir, fixture);
}

Future<OcrScan> _load(String dir, String fixture) => FixtureTextRecognizer(
  (name) => File('$dir/$name').readAsString(),
).recognize(PageImage(fixture));

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
  _Set(
    'device page',
    '$_textbook/device-iphone13mini/feedback-1747',
    _otherTruth,
    8,
    [13, 13, 12, 0],
    truthPage: 'ob1044',
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
  const _Set(
    'synthetic bracketed-reading pages',
    '$_synthetic/synthetic_general',
    '$_synthetic/synthetic_general/ground_truth_paren.json',
    9,
    [10, 10, 10, 0],
  ),
];

/// The real-use pages, at the values of their answer file.
_Set get _realUseSet {
  final want = _realUseExpected.existsSync()
      ? (_json(_realUseExpected)['values']! as List).cast<int>()
      : const [0, 0, 0, 0, 0];
  return _Set(
    'real-use pages',
    _realUse,
    '$_realUse/ground_truth.json',
    want[4],
    want.sublist(0, 4),
  );
}

/// The ML Kit word-box set (no app channel): its bounds instead of values.
_Set get _wordBoxes => _Set(
  'word-list pages, ML Kit word boxes',
  '$_textbook/ocr-android/fixtures_element',
  _vocabTruth,
  36,
  const [],
);

const int _wordBoxesMinMeanings = 56;

/// Every recorded page pair under the textbook folder: (folder, fixture).
List<(String, String)> _recordedPages() {
  final pages = <(String, String)>[];
  for (final e in Directory(_textbook).listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.ko.json')) continue;
    final base = e.path.substring(0, e.path.length - '.ko.json'.length);
    if (!File('$base.ja.json').existsSync()) continue;
    pages.add((e.parent.path, base.split('/').last));
  }
  pages.sort((a, b) => '${a.$1}/${a.$2}'.compareTo('${b.$1}/${b.$2}'));
  return pages;
}

/// Every value of [e] the review draft shows, in one string.
String _value(CapturedEntry e) {
  final ev = e.evidence;
  String cell(EntryField f) {
    final c = ev?.of(f);
    if (c == null) return '-';
    return [
      c.source.name,
      c.confidence?.name,
      c.note,
      c.candidates.join('|'),
      c.boxes.length,
    ].join('/');
  }

  return [
    e.headword,
    e.readings.join('/'),
    e.pos?.name,
    e.meaning,
    e.example?.ja,
    e.example?.ko,
    e.issues.join(','),
    e.headwordCandidates.join('|'),
    e.included,
    e.ocrHeadword,
    ev?.origin.name,
    for (final f in EntryField.values) cell(f),
  ].join('\t');
}

/// The rows of a draft: its entries, then what it leaves unpaired (marked
/// with a leading `∅`).
List<String> _rows(CaptureDraft d) => [
  for (final e in d.entries) _value(e),
  for (final f in d.unpaired) '∅${f.text}\t${f.kind.name}',
];

/// Headwords (and `∅`-marked unpaired texts) the change was approved to
/// alter, by page (`<folder below textbook>/<fixture>`).
Map<String, List<String>> get _approved => {
  for (final MapEntry(:key, :value) in _json(_changesFile).entries)
    if (!key.startsWith('_')) key: (value! as List).cast<String>(),
};

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

String? _wiktDatabase(Directory temp) {
  final fromEnv = Platform.environment['SHIORI_WIKT_GLOSSARY_DB'];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  final gz = File(
    Directory(
      _privateDir(),
    ).uri.resolve('../app/assets/dict/wikt-glossary.sqlite.gz').toFilePath(),
  );
  if (!gz.existsSync()) return null;
  final out = File('${temp.path}/wikt-glossary.sqlite')
    ..writeAsBytesSync(gzip.decode(gz.readAsBytesSync()));
  return out.path;
}

void main() {
  final temp = Directory.systemTemp.createTempSync('paren_tail_');
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
  final wiktPath = _wiktDatabase(temp);
  final write = Platform.environment['SHIORI_WRITE_VALUES'] == '1';
  final skip =
      !_sets.every((s) => s.exists) ||
          !_wordBoxes.exists ||
          !_realUseSet.exists ||
          !_realUseExpected.existsSync()
      ? 'recorded pages not found under $_textbook (local only)'
      : jmdictPath == null || glossaryPath == null || wiktPath == null
      ? 'dictionary files not found (set SHIORI_JMDICT_DB, '
            'SHIORI_KO_GLOSSARY_DB and SHIORI_WIKT_GLOSSARY_DB)'
      : null;

  JmdictDictionary? jmdict;
  KrdictGlossary? glossary;
  KrdictGlossary? wikt;
  late GeneralExtractor extractor;

  setUpAll(() {
    if (skip != null) return;
    jmdict = JmdictDictionary.open(jmdictPath!);
    glossary = KrdictGlossary.open(glossaryPath!);
    wikt = KrdictGlossary.open(wiktPath!);
    // As the app builds it (app/lib/app/blocks.dart).
    extractor = GeneralExtractor(
      lexicon: JmdictLexiconAdapter(jmdict!),
      koreanGlossary: glossary,
      meaningFallback: wikt,
    );
  });
  tearDownAll(() {
    wikt?.close();
    glossary?.close();
    jmdict?.close();
    temp.deleteSync(recursive: true);
  });

  Future<ExtractScore> run(
    _Set set, [
    OcrScan Function(OcrScan) variant = _same,
  ]) async {
    final scores = <PageExtractScore>[];
    for (final (fixture, page) in set.pages) {
      final draft = await pageDraft(
        extractor,
        variant(await set.load(fixture)),
      );
      scores.add(
        scoreExtractPage(page, [
          for (final e in draft.entries) ScoredWord.fromCaptured(e),
        ]),
      );
    }
    return ExtractScore(scores);
  }

  void printScore(String name, ExtractScore s) => print(
    '$name: high ${s.high}, high but wrong ${s.highWrong}, '
    'extra at high ${s.extraHigh}, found ${s.found}/${s.vocab} '
    'reading ${s.readingsOk} meaning ${s.meanings.ok}/${s.meanings.of} '
    'extras ${s.extras}',
  );

  test('P5 every set at its approved values; nothing wrong or extra at '
      'high; high at or above the lower bound; the real-use pages at their '
      'answers', () async {
    for (final set in [..._sets, _realUseSet]) {
      final s = await run(set);
      printScore(set.name, s);
      expect(s.highWrong, 0, reason: set.name);
      expect(s.extraHigh, 0, reason: set.name);
      expect(s.high, greaterThanOrEqualTo(set.minHigh), reason: set.name);
      expect(
        [s.found, s.readingsOk, s.meanings.ok, s.extras],
        set.values,
        reason: set.name,
      );
    }
    final full = await run(_realUseSet);
    expect(full.found, full.vocab, reason: 'real-use pages');
  }, skip: write ? 'writing the values before the change' : skip);

  test('P5 every recorded page: the review drafts as recorded before but '
      'the approved entries', () async {
    final pages = _recordedPages();
    final recorded = <String, List<String>>{};
    for (final (dir, fixture) in pages) {
      final key = '${dir.replaceFirst('$_textbook/', '')}/$fixture';
      recorded[key] = _rows(
        await pageDraft(extractor, await _load(dir, fixture)),
      );
    }
    if (write) {
      _valuesFile
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(recorded));
      return;
    }
    print('recorded pages: ${pages.length}');
    final before = _json(_valuesFile);
    expect(recorded.keys.toSet(), before.keys.toSet());
    final approved = _approved;
    for (final MapEntry(key: page, value: rows) in recorded.entries) {
      final changed = approved[page] ?? const [];
      bool kept(String row) => !changed.contains(row.split('\t').first);
      expect(
        rows.where(kept).toList(),
        [
          for (final row in (before[page]! as List).cast<String>())
            if (kept(row)) row,
        ],
        reason: 'page ${pages.indexWhere((p) => page.endsWith('/${p.$2}'))}',
      );
    }
  }, skip: skip);

  test('P5 the ML Kit word-box set: nothing wrong or extra at high, high '
      'and meanings at or above their bounds', () async {
    final s = await run(_wordBoxes);
    printScore(_wordBoxes.name, s);
    expect(s.highWrong, 0);
    expect(s.extraHigh, 0);
    expect(s.high, greaterThanOrEqualTo(_wordBoxes.minHigh));
    expect(s.meanings.ok, greaterThanOrEqualTo(_wordBoxesMinMeanings));
  }, skip: write ? 'writing the values before the change' : skip);

  for (final (passes, ja, ko) in [
    ('both passes', true, true),
    ('the Japanese pass', true, false),
    ('the Korean pass', false, true),
  ]) {
    test('P5 every line of $passes read at the lowest confidence: nothing '
        'wrong or extra at high', () async {
      for (final set in [..._sets, _realUseSet]) {
        final s = await run(set, (scan) => _lowered(scan, ja: ja, ko: ko));
        print('$passes, ${set.name}: high ${s.high}, found ${s.found}');
        expect(s.highWrong, 0, reason: set.name);
        expect(s.extraHigh, 0, reason: set.name);
      }
    }, skip: write ? 'writing the values before the change' : skip);
  }
}

OcrScan _same(OcrScan scan) => scan;
