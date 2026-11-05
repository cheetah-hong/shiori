// E2, E5, E6 on recorded pages with the real dictionaries (local only): the
// routed capture with JMdict and the Korean glossary. Skipped without the
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

/// The SQLite file of [envName], else [asset] (gzip) unpacked to a temporary
/// folder; null when neither is there.
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
  'recorded textbook pages',
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

void main() {
  final temp = Directory.systemTemp.createTempSync('routed_capture_');
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
  final skip = !_vocab.exists || !_curled.exists || !_other.exists
      ? 'recorded pages not found under $_textbook (local only)'
      : jmdictPath == null || glossaryPath == null
      ? 'dictionary files not found (set SHIORI_JMDICT_DB and SHIORI_KO_GLOSSARY_DB)'
      : null;

  JmdictDictionary? jmdict;
  KrdictGlossary? glossary;
  late CaptureRouter router;

  setUpAll(() {
    if (skip != null) return;
    jmdict = JmdictDictionary.open(jmdictPath!);
    glossary = KrdictGlossary.open(glossaryPath!);
    router = CaptureRouter(
      template: CapturePipeline.standard(
        dictionary: JmdictDictionaryAdapter(jmdict!),
        glossary: glossary,
      ),
      general: GeneralExtractor(
        lexicon: JmdictLexiconAdapter(jmdict!),
        koreanGlossary: glossary,
      ),
    );
  });
  tearDownAll(() {
    glossary?.close();
    jmdict?.close();
    temp.deleteSync(recursive: true);
  });

  Future<ExtractScore> score(_Set set) async {
    final pages = <PageExtractScore>[];
    for (final page in set.answers.pages) {
      final draft = await router.fromScan(await set.load(page.fixture));
      pages.add(
        scoreExtractPage(page, [
          for (final e in draft.entries) ScoredWord.fromCaptured(e),
        ]),
      );
    }
    return ExtractScore(pages);
  }

  test('E2 the curled phone page goes to the general extractor: every found '
      'word has the right reading, 12 or more meanings', () async {
    final s = await score(_curled);
    final p = s.pages.single;
    // Printed for the score table (numbers only).
    print(
      'curled: found ${p.found}/${p.vocab} reading ${p.readingsOk} '
      'meaning ${p.meanings.ok}/${p.meanings.of} high ${p.high} '
      'extras ${p.extras}',
    );

    expect(p.found, greaterThanOrEqualTo(13));
    expect(p.readingsOk, p.found);
    expect(p.meanings.ok, greaterThanOrEqualTo(12));
  }, skip: skip);

  test('E5 high but wrong 0 on every recorded set', () async {
    for (final set in [_vocab, _curled, _other]) {
      final s = await score(set);
      final high = s.pages.fold(0, (n, p) => n + p.high);
      final wrong = s.pages.fold(0, (n, p) => n + p.highWrong);
      print('${set.name}: high $high, high but wrong $wrong');
      expect(wrong, 0, reason: set.name);
    }
  }, skip: skip);

  test(
    'E6 the other textbook: 10 extras or fewer, every printed word found',
    () async {
      final s = await score(_other);
      final extras = s.pages.fold(0, (n, p) => n + p.extras);
      final found = s.pages.fold(0, (n, p) => n + p.found);
      final vocab = s.pages.fold(0, (n, p) => n + p.vocab);
      print('other textbook: extras $extras, found $found/$vocab');

      expect(extras, lessThanOrEqualTo(10));
      expect(found, vocab);
    },
    skip: skip,
  );
}
