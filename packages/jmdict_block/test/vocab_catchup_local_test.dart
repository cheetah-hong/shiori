// V3, V5, V6 and the curled phone page (local only, real dictionaries): the
// general extractor alone, with JMdict and the Korean glossary, on the
// recorded word-list pages, the synthetic pages and the other sets. Skipped
// without the dictionary files (SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB,
// SQLite; else the app's gzip assets next to $SHIORI_PRIVATE_DIR), and the
// recorded sets without $SHIORI_PRIVATE_DIR/textbook.
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

  ExtractTruth get answers => ExtractTruth.fromAnyJson(
    (jsonDecode(File(truth).readAsStringSync()) as Map).cast<String, Object?>(),
  );

  Future<OcrScan> load(String fixture) => FixtureTextRecognizer(
    (name) => File('$dir/$name').readAsString(),
  ).recognize(PageImage(fixture));
}

final _vocab = _Set(
  'recorded word-list pages',
  '$_textbook/vocab_n5n3',
  '$_textbook/vocab_n5n3/general/ground_truth.json',
);
final _curled = _Set(
  'curled phone page',
  '$_textbook/device-iphone13mini/fixtures',
  '$_textbook/device-iphone13mini/general/ground_truth.json',
);
final _other = _Set(
  'other textbook',
  '$_textbook/other-books/fixtures',
  '$_textbook/other-books/ground_truth.json',
);
const _syntheticOld = _Set(
  'synthetic word-list pages',
  '../core/test/fixtures/synthetic',
  '../core/test/fixtures/synthetic/ground_truth.json',
);
const _syntheticGeneral = _Set(
  'synthetic general pages',
  '../core/test/fixtures/synthetic_general',
  '../core/test/fixtures/synthetic_general/ground_truth.json',
);

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

/// Full-width brackets as ASCII ones (`（お）` → `(お)`).
String _bracketsAscii(String s) => s.replaceAll('（', '(').replaceAll('）', ')');

void main() {
  final temp = Directory.systemTemp.createTempSync('vocab_catchup_');
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
  final noPages = !_vocab.exists || !_curled.exists || !_other.exists
      ? 'recorded pages not found under $_textbook (local only)'
      : null;
  final skipRecorded = noDictionary ?? noPages;

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

  Future<ExtractScore> score(
    _Set set, {
    Set<String>? pages,
    OcrScan Function(OcrScan)? change,
  }) async {
    final out = <PageExtractScore>[];
    for (final page in set.answers.pages) {
      if (pages != null && !pages.contains(page.fixture)) continue;
      final scan = await set.load(page.fixture);
      final r = await general.extract(change == null ? scan : change(scan));
      out.add(
        scoreExtractPage(page, [
          for (final w in r.words) ScoredWord.fromExtracted(w),
        ]),
      );
    }
    return ExtractScore(out);
  }

  void show(String name, ExtractScore s) => print(
    // Printed for the score table (numbers only).
    '$name: found ${s.found}/${s.vocab} reading ${s.readingsOk} meaning '
    '${s.pages.fold(0, (n, p) => n + p.meanings.ok)}/'
    '${s.pages.fold(0, (n, p) => n + p.meanings.of)} sentence '
    '${s.pages.fold(0, (n, p) => n + p.sentenceWords.ok)}/'
    '${s.pages.fold(0, (n, p) => n + p.sentenceWords.of)} extras '
    '${s.extras} high ${s.pages.fold(0, (n, p) => n + p.high)} '
    'highWrong ${s.highWrong}',
  );

  int meaningsWrong(ExtractScore s) =>
      s.pages.fold(0, (n, p) => n + p.meanings.of - p.meanings.ok);

  test('V6 the recorded word-list pages, general extractor alone: found 58 '
      'or more of 59, every reading right, 2 or fewer meanings wrong, 3 or '
      'fewer extras', () async {
    final s = await score(_vocab);
    show('word-list pages', s);
    expect(s.vocab, 59);
    expect(s.found, greaterThanOrEqualTo(58));
    expect(s.readingsOk, s.found);
    expect(meaningsWrong(s), lessThanOrEqualTo(2));
    expect(s.extras, lessThanOrEqualTo(3));
    expect(s.highWrong, 0);
  }, skip: skipRecorded);

  test('the curled phone page, as recorded and with its blank cells read '
      'as 一 at 0.5: every word, no extras, the parenthesized-prefix row '
      'keeps its printed meaning', () async {
    // The row printed with an optional prefix in brackets, from the answers.
    final prefixed = _curled.answers.pages.single.vocab.singleWhere(
      (v) => _bracketsAscii(v.headword).startsWith('('),
    );
    for (final (name, change) in [
      ('as recorded', null),
      ('dash read as 一', _dashAsKanji),
    ]) {
      final s = await score(_curled, change: change);
      show('curled page, $name', s);
      expect(s.vocab, 15, reason: name);
      expect(s.found, 15, reason: name);
      expect(s.readingsOk, 15, reason: name);
      expect(meaningsWrong(s), 0, reason: name);
      expect(s.extras, 0, reason: name);
      expect(s.highWrong, 0, reason: name);

      final scan = await _curled.load(_curled.answers.pages.single.fixture);
      final r = await general.extract(change == null ? scan : change(scan));
      final word = r.words.singleWhere(
        (w) => _bracketsAscii(w.headword) == _bracketsAscii(prefixed.headword),
      );
      expect(word.meaning, prefixed.meaning, reason: name);
    }
  }, skip: skipRecorded);

  test('the other textbook does not get worse: 15/15 found and read, 11 or '
      'more meanings, 30 or more of 33 sentence words, 4 or fewer '
      'extras', () async {
    final s = await score(_other);
    show('other textbook', s);
    expect(s.found, 15);
    expect(s.readingsOk, 15);
    expect(
      s.pages.fold(0, (n, p) => n + p.meanings.ok),
      greaterThanOrEqualTo(11),
    );
    expect(
      s.pages.fold(0, (n, p) => n + p.sentenceWords.ok),
      greaterThanOrEqualTo(30),
    );
    expect(s.extras, lessThanOrEqualTo(4));
    expect(s.highWrong, 0);
  }, skip: skipRecorded);

  test('V5 the synthetic word-list pages through the general extractor: '
      'found 32 or more of 35, 1 or fewer meanings wrong, 8 or fewer '
      'extras', () async {
    final s = await score(_syntheticOld);
    show('synthetic word-list pages', s);
    expect(s.vocab, 35);
    expect(s.found, greaterThanOrEqualTo(32));
    expect(s.readingsOk, s.found);
    expect(meaningsWrong(s), lessThanOrEqualTo(1));
    expect(s.extras, lessThanOrEqualTo(8));
    expect(s.highWrong, 0);
  }, skip: noDictionary);

  test('V3 the synthetic general pages g01–g06 with the real dictionaries: '
      'found 49/49, readings 49/49, meanings 48/48, sentence words 45/45, '
      'no extras', () async {
    final s = await score(
      _syntheticGeneral,
      pages: {'g01', 'g02', 'g03', 'g04', 'g05', 'g06'},
    );
    show('synthetic general g01–g06', s);
    expect(s.found, 49);
    expect(s.readingsOk, 49);
    expect(s.pages.fold(0, (n, p) => n + p.meanings.ok), 48);
    expect(s.pages.fold(0, (n, p) => n + p.sentenceWords.ok), 45);
    expect(s.extras, 0);
    expect(s.highWrong, 0);
  }, skip: noDictionary);

  test('the new synthetic pages g10 and g11 with the real dictionaries: '
      'every printed word, no extras', () async {
    final s = await score(_syntheticGeneral, pages: {'g10', 'g11'});
    show('synthetic general g10–g11', s);
    expect(s.found, s.vocab);
    expect(s.readingsOk, s.found);
    expect(meaningsWrong(s), 0);
    expect(s.extras, 0);
    expect(s.highWrong, 0);
  }, skip: noDictionary);
}
