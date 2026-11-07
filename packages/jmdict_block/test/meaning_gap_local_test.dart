// W6 on recorded pages and the synthetic sets with the real dictionaries
// (local only): the Wiktionary fallback glossary fills a dictionary word's
// meaning only where the Basic Korean Dictionary gives none. On the 74
// printed words the first sense names the printed meaning for at least 56,
// one of five senses for at least 65 (54 and 63 without the fallback). On
// every set the only values that change are meanings that were empty;
// found, readings and extras stay at their approved values, meanings right
// do not fall, nothing is wrong or extra at high, high at or above the lower
// bound, and no meaning from the fallback is high. Prints numbers only.
// Skipped without the recorded pages ($SHIORI_PRIVATE_DIR/textbook) or the
// dictionary files (SHIORI_JMDICT_DB, SHIORI_KO_GLOSSARY_DB and
// SHIORI_WIKT_GLOSSARY_DB, SQLite; else the gzip assets of this checkout's
// app, else those next to the private folder).
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

  /// found, readings right, meanings right, extras (approved,
  /// docs/verification.md 27 and 30).
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

/// This checkout's asset [asset] (gzip) unpacked to [temp], else
/// [_database]'s.
String? _wiktDatabase(Directory temp) {
  const asset = 'wikt-glossary.sqlite.gz';
  final fromEnv = Platform.environment['SHIORI_WIKT_GLOSSARY_DB'];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  final here = File(
    Directory.current.uri.resolve('../../app/assets/dict/$asset').toFilePath(),
  );
  if (!here.existsSync()) {
    return _database('SHIORI_WIKT_GLOSSARY_DB', asset, temp);
  }
  final out = File('${temp.path}/wikt-glossary.sqlite')
    ..writeAsBytesSync(gzip.decode(here.readAsBytesSync()));
  return out.path;
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

bool _names(KoreanSense s, Set<String> answer) =>
    s.words.map(_norm).any(answer.contains);

void main() {
  final temp = Directory.systemTemp.createTempSync('meaning_gap_');
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
  final skip = !_sets.every((s) => s.exists) || !_wordBoxes.exists
      ? 'recorded pages not found under $_textbook (local only)'
      : jmdictPath == null || glossaryPath == null || wiktPath == null
      ? 'dictionary files not found (set SHIORI_JMDICT_DB, '
            'SHIORI_KO_GLOSSARY_DB and SHIORI_WIKT_GLOSSARY_DB)'
      : null;

  JmdictDictionary? jmdict;
  KrdictGlossary? glossary;
  KrdictGlossary? wikt;
  late JmdictLexiconAdapter lexicon;
  late GeneralExtractor alone;
  late GeneralExtractor withFallback;

  setUpAll(() {
    if (skip != null) return;
    jmdict = JmdictDictionary.open(jmdictPath!);
    glossary = KrdictGlossary.open(glossaryPath!);
    wikt = KrdictGlossary.open(wiktPath!);
    lexicon = JmdictLexiconAdapter(jmdict!);
    alone = GeneralExtractor(lexicon: lexicon, koreanGlossary: glossary);
    withFallback = GeneralExtractor(
      lexicon: lexicon,
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

  Future<(ExtractScore, Map<String, List<CapturedEntry>>)> run(
    _Set set,
    GeneralExtractor extractor,
  ) async {
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

  bool fromWiktionary(CapturedEntry e) =>
      e.evidence?.of(EntryField.meaning)?.note?.contains('위키낱말사전') ?? false;

  test('W6 the 74 printed words: first sense at least 56, one of five at '
      'least 65 with the fallback; 54 and 63 without', () async {
    final words = <(String, List<String>, String)>[];
    for (final file in [_vocabTruth, _curledTruth]) {
      for (final p in ExtractTruth.fromJson(_json(File(file))).pages) {
        for (final v in p.vocab) {
          final m = v.meaning;
          if (v.headword.isEmpty || m == null || m.trim().isEmpty) continue;
          words.add((v.headword, v.readings, m));
        }
      }
    }
    expect(words, hasLength(74));
    final entries = await lexicon.lookup({for (final w in words) w.$1});
    final both = FallbackKoreanGlossary(glossary!, wikt!);
    final counts = <String, (int, int)>{};
    for (final (label, g) in <(String, KoreanGlossary)>[
      ('alone', glossary!),
      ('fallback', both),
    ]) {
      var first = 0, within = 0;
      for (final (headword, readings, meaning) in words) {
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
          g,
          headword,
          readings: readings,
          pos: entry == null ? null : partOfSpeechOf(entry.partsOfSpeech),
        );
        final answer = _answerWords(meaning);
        if (senses.isNotEmpty && _names(senses.first, answer)) first++;
        if (senses.any((s) => _names(s, answer))) within++;
      }
      counts[label] = (first, within);
      print('74 words, $label: first sense $first, within five $within');
    }
    expect(counts['alone'], (54, 63));
    expect(counts['fallback']!.$1, greaterThanOrEqualTo(56));
    expect(counts['fallback']!.$2, greaterThanOrEqualTo(65));
  }, skip: skip);

  test('W6 every set: only empty meanings change; found, readings and '
      'extras at their approved values, meanings right do not fall; nothing '
      'wrong or extra at high; no fallback meaning high', () async {
    var filled = 0, emptyBefore = 0;
    for (final set in _sets) {
      final (before, wasDrafts) = await run(set, alone);
      final (after, drafts) = await run(set, withFallback);
      printScore(set.name, after);
      expect(after.highWrong, 0, reason: set.name);
      expect(after.extraHigh, 0, reason: set.name);
      expect(after.high, greaterThanOrEqualTo(set.minHigh), reason: set.name);
      expect(after.high, before.high, reason: set.name);
      expect(
        [after.found, after.readingsOk, after.extras],
        [set.values[0], set.values[1], set.values[3]],
        reason: set.name,
      );
      expect(after.meanings.ok, greaterThanOrEqualTo(set.values[2]));
      expect(after.meanings.ok, greaterThanOrEqualTo(before.meanings.ok));
      for (final MapEntry(key: fixture, value: entries) in drafts.entries) {
        final was = wasDrafts[fixture]!;
        expect(entries.length, was.length, reason: '${set.name} $fixture');
        for (var i = 0; i < entries.length; i++) {
          final e = entries[i];
          if (was[i].meaning.isEmpty) emptyBefore++;
          if (was[i].meaning.isEmpty && e.meaning.isNotEmpty) {
            filled++;
            expect(fromWiktionary(e), isTrue, reason: e.headword);
            expect(
              e.evidence?.of(EntryField.meaning)?.confidence,
              PairConfidence.medium,
            );
            expect(e.headword, was[i].headword);
            continue;
          }
          expect(_value(e), _value(was[i]), reason: '${set.name} entry $i');
        }
      }
    }
    print('empty meanings $emptyBefore, filled from the fallback $filled');
    expect(filled, greaterThan(0));
  }, skip: skip);

  test('W6 the ML Kit word-box set: bounds kept with the fallback', () async {
    final (s, drafts) = await run(_wordBoxes, withFallback);
    printScore(_wordBoxes.name, s);
    expect(s.highWrong, 0);
    expect(s.extraHigh, 0);
    expect(s.high, greaterThanOrEqualTo(_wordBoxes.minHigh));
    expect(s.meanings.ok, greaterThanOrEqualTo(_wordBoxesMinMeanings));
    for (final e in drafts.values.expand((x) => x)) {
      if (fromWiktionary(e)) {
        expect(
          e.evidence?.of(EntryField.meaning)?.confidence,
          PairConfidence.medium,
        );
      }
    }
  }, skip: skip);
}
