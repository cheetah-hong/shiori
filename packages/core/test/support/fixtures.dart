import 'dart:convert';
import 'dart:io';

import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';

/// A folder of recorded OCR passes (`<page>.ja.json`, `<page>.ko.json`)
/// with `ground_truth.json` (`"format": "general-1"`).
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

  ExtractTruth get truth => ExtractTruth.fromJson(
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

/// Made-up word-book pages with the OCR mistakes a reader must survive
/// (tools/synthetic/make_pages.py). In the repository; always tested.
const synthetic = FixtureSet('synthetic pages', 'test/fixtures/synthetic');

/// The same made-up pages as the ML Kit channel returns them (pieces cut at
/// column gaps, ML Kit's slips). In the repository; always tested.
const syntheticMlKit = FixtureSet(
  'synthetic pages, ML Kit',
  'test/fixtures/synthetic_mlkit',
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

Future<OcrScan> loadScan(String fixture) => synthetic.loadScan(fixture);
