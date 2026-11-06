// Q6 on recorded pages and the synthetic sets with the real dictionaries
// (local only): an adverb before a negative, an expression read as its
// verb, the sentence words left out (one kana, a kanji after a number, a
// related-word note) and the word boxes of one Korean line joined leave
// every set at its approved values (found, readings right, meanings right,
// extras), nothing wrong or extra at high and high at or above the lower
// bound; the ML Kit word-box set at its approved bounds. Every set but the
// word-box one keeps the values recorded before the change, except the
// entries the change was approved to alter (snapshots, local), which the
// judgement file checks. Prints numbers only. Skipped without the recorded
// pages ($SHIORI_PRIVATE_DIR/textbook) or the dictionary files
// (SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB, SQLite; else the app's gzip
// assets next to the private folder). The values before the change are
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
    File('$_textbook/snapshots/extract-values-before-small-quality.json');

File get _changesFile =>
    File('$_textbook/snapshots/small-quality-changes.json');

File get _judgementFile =>
    File('$_textbook/snapshots/small-quality-judgement.json');

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

  /// Lower bound of high entries (docs/verification.md 22).
  final int minHigh;

  /// found, readings right, meanings right, extras (approved for this
  /// change, docs/verification.md 27).
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
];

/// The ML Kit word-box set (no app channel): its bounds instead of values.
_Set get _wordBoxes => _Set(
  'word-list pages, ML Kit word boxes',
  '$_textbook/ocr-android/fixtures_element',
  _vocabTruth,
  36,
  const [],
);

const int _wordBoxesMinMeanings = 56;

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

/// Headwords the change was approved to alter, by set and page.
Map<String, Map<String, List<String>>> get _approved => {
  for (final MapEntry(:key, :value) in _json(_changesFile).entries)
    if (!key.startsWith('_'))
      key: {
        for (final MapEntry(key: page, value: heads)
            in (value! as Map).cast<String, Object?>().entries)
          page: (heads! as List).cast<String>(),
      },
};

void main() {
  final temp = Directory.systemTemp.createTempSync('small_quality_');
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
  final write = Platform.environment['SHIORI_WRITE_VALUES'] == '1';
  final skip = !_sets.every((s) => s.exists) || !_wordBoxes.exists
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

  /// The set's score and its drafts' values by fixture.
  Future<(ExtractScore, Map<String, List<CapturedEntry>>)> run(_Set set) async {
    final scores = <PageExtractScore>[];
    final drafts = <String, List<CapturedEntry>>{};
    for (final (fixture, page) in set.pages) {
      final draft = await pageDraft(extractor, await set.load(fixture));
      drafts[fixture] = draft.entries;
      scores.add(
        scoreExtractPage(page, [
          for (final e in draft.entries) ScoredWord.fromCaptured(e),
        ]),
      );
    }
    return (ExtractScore(scores), drafts);
  }

  void printScore(String name, ExtractScore s) => print(
    '$name: high ${s.high}, high but wrong ${s.highWrong}, '
    'extra at high ${s.extraHigh}, found ${s.found}/${s.vocab} '
    'reading ${s.readingsOk} meaning ${s.meanings.ok}/${s.meanings.of} '
    'extras ${s.extras}',
  );

  test('Q6 every set at its approved values; nothing wrong or extra at '
      'high; high at or above the lower bound; values as recorded before '
      'but the approved entries', () async {
    final recorded = <String, Object?>{};
    final before = write ? null : _json(_valuesFile);
    final approved = write
        ? const <String, Map<String, List<String>>>{}
        : _approved;
    for (final set in _sets) {
      final (s, drafts) = await run(set);
      final values = {
        for (final MapEntry(key: fixture, value: entries) in drafts.entries)
          fixture: [for (final e in entries) _value(e)],
      };
      recorded[set.name] = values;
      if (write) continue;
      printScore(set.name, s);
      expect(s.highWrong, 0, reason: set.name);
      expect(s.extraHigh, 0, reason: set.name);
      expect(s.high, greaterThanOrEqualTo(set.minHigh), reason: set.name);
      expect(
        [s.found, s.readingsOk, s.meanings.ok, s.extras],
        set.values,
        reason: set.name,
      );
      final was = (before![set.name]! as Map).cast<String, Object?>();
      final changed = approved[set.name] ?? const {};
      for (final MapEntry(key: fixture, value: rows) in values.entries) {
        bool kept(String row) =>
            !(changed[fixture]?.contains(row.split('\t').first) ?? false);
        expect(
          rows.where(kept).toList(),
          [
            for (final row in (was[fixture]! as List).cast<String>())
              if (kept(row)) row,
          ],
          reason: '${set.name} ${values.keys.toList().indexOf(fixture)}',
        );
      }
    }
    if (write) {
      _valuesFile
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(recorded));
    }
  }, skip: skip);

  test('Q6 the ML Kit word-box set: nothing wrong or extra at high, high '
      'and meanings at or above their bounds', () async {
    final (s, _) = await run(_wordBoxes);
    printScore(_wordBoxes.name, s);
    expect(s.highWrong, 0);
    expect(s.extraHigh, 0);
    expect(s.high, greaterThanOrEqualTo(_wordBoxes.minHigh));
    expect(s.meanings.ok, greaterThanOrEqualTo(_wordBoxesMinMeanings));
  }, skip: write ? 'writing the values before the change' : skip);

  test(
    'Q6 the approved entries: as the judgement file says',
    () async {
      final judged = _json(_judgementFile);
      for (final set in _sets) {
        final pages = (judged[set.name] as Map?)?.cast<String, Object?>();
        if (pages == null) continue;
        final (_, drafts) = await run(set);
        for (final MapEntry(key: fixture, value: want) in pages.entries) {
          final w = (want! as Map).cast<String, Object?>();
          final entries = drafts[fixture]!;
          final heads = [for (final e in entries) e.headword];
          final at = '${set.name} ${drafts.keys.toList().indexOf(fixture)}';
          for (final h in ((w['absent'] as List?) ?? const []).cast<String>()) {
            expect(heads, isNot(contains(h)), reason: 'absent $at');
          }
          for (final h
              in ((w['present'] as List?) ?? const []).cast<String>()) {
            expect(heads, contains(h), reason: 'present $at');
          }
          for (final MapEntry(key: h, value: m)
              in ((w['meanings'] as Map?) ?? const {})
                  .cast<String, String>()
                  .entries) {
            expect(
              entries.firstWhere((e) => e.headword == h).meaning,
              m,
              reason: 'meaning $at',
            );
          }
        }
      }
    },
    skip: write ? 'writing the values before the change' : skip,
  );
}
