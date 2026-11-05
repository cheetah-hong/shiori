import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/shiori_core.dart';

/// A folder of recorded OCR passes (`<page>.ja.json`, `<page>.ko.json`)
/// with `ground_truth.json` and `reference_output.json`.
final class FixtureSet {
  const FixtureSet(this.name, this.dir);

  final String name;
  final String dir;

  bool get exists => File('$dir/ground_truth.json').existsSync();

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

/// Recorded OCR of real textbook pages. Textbook content, so it is kept out of
/// the repository: `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3`, where
/// `SHIORI_PRIVATE_DIR` defaults to `<repo>/.private`. Tests on it are skipped
/// when it is missing.
final FixtureSet recordedTextbook = FixtureSet(
  'recorded textbook pages',
  '${privateDir()}/textbook/vocab_n5n3',
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
