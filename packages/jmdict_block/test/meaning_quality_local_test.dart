// M6, M7, M9 on recorded pages and the synthetic sets with the real
// dictionaries (local only): the meanings the dictionary fills, and their
// candidates, are the only values that change; every set keeps its scores
// and its lower bound of high entries with nothing wrong or extra at high,
// and no meaning filled from the dictionary is high. On the 74 printed words
// of the word-list pages and the curled page the first sense names the
// printed meaning for at least 54, and one of the five senses for at least
// 63. Prints numbers only. Skipped without the recorded pages
// ($SHIORI_PRIVATE_DIR/textbook) or the dictionary files (SHIORI_JMDICT_DB
// and SHIORI_KO_GLOSSARY_DB, SQLite; else the app's gzip assets next to the
// private folder).
//
// The values before the change are written once with SHIORI_WRITE_VALUES=1
// (to $SHIORI_PRIVATE_DIR/textbook/snapshots).
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
    File('$_textbook/snapshots/extract-values-before-meaning-quality.json');

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
  const _Set(this.name, this.dir, this.truth, this.minHigh, this.values);

  final String name;
  final String dir;
  final String truth;

  /// Lower bound of high entries (docs/verification.md 22).
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

/// One entry as compared before and after: every value, where the meaning
/// came from, the confidence of each cell and the candidates.
Map<String, Object?> _entry(CapturedEntry e) {
  final meaning = e.evidence?.of(EntryField.meaning);
  final reading = e.evidence?.of(EntryField.readings);
  return {
    'headword': e.headword,
    'readings': e.readings,
    'pos': e.pos?.name,
    'meaning': e.meaning,
    'meaningSource': meaning?.source.name,
    'meaningConfidence': meaning?.confidence?.name,
    'meaningCandidates': meaning?.candidates ?? const <String>[],
    'readingSource': reading?.source.name,
    'readingConfidence': reading?.confidence?.name,
    'headwordCandidates': e.headwordCandidates,
    'example': [e.example?.ja, e.example?.ko],
    'issues': [for (final i in e.issues) '${i.field.name}:${i.kind.name}'],
  };
}

/// [e] without what this change may alter: the meaning of a word whose
/// meaning came from the dictionary, and the meaning candidates.
Map<String, Object?> _fixedPart(Map<String, Object?> e) => {
  for (final MapEntry(:key, :value) in e.entries)
    if (key != 'meaningCandidates' &&
        !(key == 'meaning' &&
            e['meaningSource'] == FieldSource.dictionary.name))
      key: value,
};

/// A headword as the score table matches it: no spaces, no だ after a
/// な-adjective.
String _headwordKey(String h) {
  final x = h.replaceAll(RegExp(r'\s+'), '');
  return x.endsWith('だ') && x.length > 1 ? x.substring(0, x.length - 1) : x;
}

String _norm(String w) => w.replaceAll(RegExp(r'\s+'), '').trim();

/// `갈아타다, 환승하다` or `(교통) 정체` → {갈아타다, 환승하다} / {정체}.
Set<String> _answerWords(String meaning) => {
  for (final w
      in meaning
          .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
          .split(RegExp('[,，、/·;~]')))
    if (_norm(w).isNotEmpty) _norm(w),
};

/// Entries a later change was approved to alter on [set], by page
/// (snapshots/conj-mixed-changes.json): left out of the comparison with the
/// values recorded before (conj_mixed_local_test checks them).
Map<String, List<String>> _approvedChanges(String set) {
  final f = File('$_textbook/snapshots/conj-mixed-changes.json');
  if (!f.existsSync()) return const {};
  final all = (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
  return {
    for (final MapEntry(:key, :value)
        in ((all[set] as Map?) ?? const {}).cast<String, Object?>().entries)
      key: (value! as List).cast<String>(),
  };
}

bool _names(KoreanSense s, Set<String> answer) =>
    s.words.map(_norm).any(answer.contains);

void main() {
  final temp = Directory.systemTemp.createTempSync('meaning_quality_');
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
  late Lexicon lexicon;

  setUpAll(() {
    if (skip != null) return;
    jmdict = JmdictDictionary.open(jmdictPath!);
    glossary = KrdictGlossary.open(glossaryPath!);
    lexicon = JmdictLexiconAdapter(jmdict!);
    extractor = GeneralExtractor(lexicon: lexicon, koreanGlossary: glossary);
  });
  tearDownAll(() {
    glossary?.close();
    jmdict?.close();
    temp.deleteSync(recursive: true);
  });

  test('M7 M9 only the dictionary\'s meanings and the candidates change; '
      'scores, high entries and their bounds hold', () async {
    final write = Platform.environment['SHIORI_WRITE_VALUES'] == '1';
    final before = _valuesFile.existsSync()
        ? (jsonDecode(_valuesFile.readAsStringSync()) as Map)
              .cast<String, Object?>()
        : null;
    expect(write || before != null, isTrue, reason: 'no values recorded');
    final recorded = <String, Object?>{};
    var filled = 0, firstChanged = 0, candidatesChanged = 0;
    for (final set in _sets) {
      final pages = <PageExtractScore>[];
      final values = <String, List<Map<String, Object?>>>{};
      var filledHigh = 0;
      for (final page in set.answers.pages) {
        final draft = await pageDraft(extractor, await set.load(page.fixture));
        values[page.fixture] = [for (final e in draft.entries) _entry(e)];
        pages.add(
          scoreExtractPage(page, [
            for (final e in draft.entries) ScoredWord.fromCaptured(e),
          ]),
        );
        for (final e in draft.entries) {
          final cell = e.evidence?.of(EntryField.meaning);
          if (cell?.source == FieldSource.dictionary &&
              cell?.confidence == PairConfidence.high) {
            filledHigh++;
          }
        }
      }
      final s = ExtractScore(pages);
      print(
        '${set.name}: high ${s.high}, high but wrong ${s.highWrong}, '
        'extra at high ${s.extraHigh}, found ${s.found}/${s.vocab} '
        'reading ${s.readingsOk} meaning ${s.meanings.ok}/${s.meanings.of} '
        'extras ${s.extras}',
      );
      recorded[set.name] = values;
      expect(s.highWrong, 0, reason: set.name);
      expect(s.extraHigh, 0, reason: set.name);
      expect(filledHigh, 0, reason: '${set.name}: a filled meaning at high');
      expect(
        [s.found, s.readingsOk, s.meanings.ok, s.extras],
        set.values,
        reason: set.name,
      );
      expect(s.high, greaterThanOrEqualTo(set.minHigh), reason: set.name);
      if (write) continue;
      final old = (before![set.name] as Map).cast<String, Object?>();
      final approved = _approvedChanges(set.name);
      for (final MapEntry(key: fixture, value: all) in values.entries) {
        bool kept(Map<String, Object?> e) =>
            !(approved[fixture]?.contains(e['headword']) ?? false);
        final now = all.where(kept).toList();
        final was = [
          for (final e in old[fixture] as List)
            if (kept((e as Map).cast<String, Object?>()))
              e.cast<String, Object?>(),
        ];
        expect(now.length, was.length, reason: '${set.name} $fixture');
        for (var i = 0; i < now.length; i++) {
          expect(
            jsonEncode(_fixedPart(now[i])),
            jsonEncode(_fixedPart(was[i])),
            reason: '${set.name} $fixture entry $i',
          );
          if (now[i]['meaningSource'] == FieldSource.dictionary.name) {
            filled++;
            if (now[i]['meaning'] != was[i]['meaning']) firstChanged++;
          }
          if (jsonEncode(now[i]['meaningCandidates']) !=
              jsonEncode(was[i]['meaningCandidates'])) {
            candidatesChanged++;
          }
        }
      }
    }
    if (write) {
      _valuesFile
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(recorded));
      return;
    }
    print(
      'filled meanings $filled: first changed $firstChanged; '
      'entries with other candidates $candidatesChanged',
    );
  }, skip: skip);

  test('M6 the first sense names the printed meaning for at least 54 of the '
      '74 words, one of five senses for at least 63', () async {
    final words = <(String, List<String>, String)>[];
    for (final file in [_vocabTruth, _curledTruth]) {
      final truth = ExtractTruth.fromJson(
        (jsonDecode(File(file).readAsStringSync()) as Map)
            .cast<String, Object?>(),
      );
      for (final p in truth.pages) {
        for (final v in p.vocab) {
          final m = v.meaning;
          if (v.headword.isEmpty || m == null || m.trim().isEmpty) continue;
          words.add((v.headword, v.readings, m));
        }
      }
    }
    expect(words, hasLength(74));
    final entries = await lexicon.lookup({for (final w in words) w.$1});
    var first = 0, within = 0;
    for (final (headword, readings, meaning) in words) {
      // The class the review screen shows: the entry with the printed
      // reading, else the first.
      final found = entries[headword] ?? const <LexiconEntry>[];
      final withReading = found.where(
        (e) => readings.isEmpty || e.readings.any(readings.contains),
      );
      final entry = withReading.isNotEmpty
          ? withReading.first
          : found.isEmpty
          ? null
          : found.first;
      final senses = await meaningSensesOf(
        glossary!,
        headword,
        readings: readings,
        pos: entry == null ? null : partOfSpeechOf(entry.partsOfSpeech),
      );
      expect(senses.length, lessThanOrEqualTo(meaningSenses));
      final answer = _answerWords(meaning);
      if (senses.isNotEmpty && _names(senses.first, answer)) first++;
      if (senses.any((s) => _names(s, answer))) within++;
    }
    print('74 words: first sense $first, within five $within');
    expect(first, greaterThanOrEqualTo(54));
    expect(within, greaterThanOrEqualTo(63));
  }, skip: skip);

  test(
    'M6 the filled meanings with a printed answer: 12 of 14 right',
    () async {
      var judged = 0, right = 0;
      for (final set in _sets) {
        for (final page in set.answers.pages) {
          final draft = await pageDraft(
            extractor,
            await set.load(page.fixture),
          );
          final answers = {
            for (final v in page.vocab) _headwordKey(v.headword): v.meaning,
          };
          for (final e in draft.entries) {
            final cell = e.evidence?.of(EntryField.meaning);
            final want = answers[_headwordKey(e.headword)];
            if (cell?.source != FieldSource.dictionary || want == null) {
              continue;
            }
            judged++;
            final answer = _answerWords(want);
            if (_answerWords(e.meaning).any(answer.contains)) right++;
          }
        }
      }
      print('filled meanings with a printed answer: $right of $judged');
      expect(judged, 14);
      expect(right, greaterThanOrEqualTo(12));
    },
    skip: skip,
  );
}
