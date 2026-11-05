import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

/// A folder of recorded OCR passes (`<page>.ja.json`, `<page>.ko.json`)
/// with `ground_truth.json` and `reference_output.json`.
///
/// [truthDir]: where `ground_truth.json` is, when the folder only holds OCR
/// passes (other image variants of the same pages).
final class FixtureSet {
  const FixtureSet(this.name, this.dir, {this.truthDir});

  final String name;
  final String dir;
  final String? truthDir;

  bool get exists =>
      File('${truthDir ?? dir}/ground_truth.json').existsSync() &&
      File('$dir/${_firstPage()}.ja.json').existsSync();

  String _firstPage() {
    final truth = File('${truthDir ?? dir}/ground_truth.json');
    if (!truth.existsSync()) return '';
    final pages =
        (jsonDecode(truth.readAsStringSync()) as Map)['pages'] as List;
    return pages.isEmpty ? '' : (pages.first as Map)['fixture'] as String;
  }

  GroundTruth get truth => GroundTruth.fromJson(
    (jsonDecode(File('${truthDir ?? dir}/ground_truth.json').readAsStringSync())
            as Map)
        .cast<String, Object?>(),
  );

  Future<String> readText(String fileName) =>
      File('$dir/$fileName').readAsString();

  Map<String, Object?> readJson(String fileName) =>
      (jsonDecode(File('$dir/$fileName').readAsStringSync()) as Map)
          .cast<String, Object?>();

  FixtureTextRecognizer get recognizer => FixtureTextRecognizer(readText);

  Future<OcrScan> loadScan(String fixture) =>
      recognizer.recognize(PageImage(fixture));
}

/// Made-up pages laid out like the textbook, with the OCR mistakes the rules
/// handle (tools/synthetic/make_pages.py). In the repository; always tested.
const synthetic = FixtureSet('synthetic pages', 'test/fixtures/synthetic');

/// The same made-up pages as the ML Kit channel returns them (pieces cut at
/// column gaps, ML Kit's slips). In the repository; always tested.
const syntheticMlKit = FixtureSet(
  'synthetic pages, ML Kit',
  'test/fixtures/synthetic_mlkit',
);

/// Recorded OCR of real textbook pages. Textbook content, so it is kept out of
/// the repository: `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3`, where
/// `SHIORI_PRIVATE_DIR` defaults to `<repo>/.private`. Tests on it are skipped
/// when it is missing.
final FixtureSet recordedTextbook = FixtureSet(
  'recorded textbook pages',
  '${privateDir()}/textbook/vocab_n5n3',
);

String get _textbook => '${privateDir()}/textbook';

/// Local only: the textbook pages read by ML Kit on an Android emulator, in
/// the pieces the channel returns.
final FixtureSet recordedMlKit = FixtureSet(
  'recorded textbook pages, ML Kit',
  '$_textbook/ocr-android/fixtures_segment',
  truthDir: '$_textbook/vocab_n5n3',
);

/// Local only: Vision passes over the page cut out of the photo and
/// perspective-corrected (scanner-like frame).
final FixtureSet recordedPageCrop = FixtureSet(
  'recorded textbook pages, page crop',
  '$_textbook/scan/fixtures/a-persp-page',
  truthDir: '$_textbook/vocab_n5n3',
);

String privateDir() {
  final fromEnv = Platform.environment['SHIORI_PRIVATE_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // `dart test` runs in packages/core.
  return Directory.current.uri.resolve('../../.private').toFilePath();
}

/// `skip:` value for tests on [set]: null when its data is there.
String? skipUnlessPresent(FixtureSet set) => set.exists
    ? null
    : '${set.name} not found in ${set.dir} '
          '(local only; set SHIORI_PRIVATE_DIR to the folder that holds textbook/)';

const fixtureRecognizer = FixtureTextRecognizer(_readSynthetic);

Future<String> _readSynthetic(String fileName) => synthetic.readText(fileName);

Future<OcrScan> loadScan(String fixture) => synthetic.loadScan(fixture);

CapturePipeline standardPipeline({
  Dictionary dictionary = const EmptyDictionary(),
}) => CapturePipeline.standard(dictionary: dictionary);

/// Cells where the Dart parser differs from the reference output on purpose.
const intendedDifferencesFile = 'intended_differences.json';

List<CellDifference> readIntendedDifferences(FixtureSet set) {
  final file = File('${set.dir}/$intendedDifferencesFile');
  if (!file.existsSync()) return const [];
  final json = jsonDecode(file.readAsStringSync()) as Map;
  return [
    for (final d in (json['differences'] as List).cast<Map<String, Object?>>())
      CellDifference.fromJson(d),
  ];
}
