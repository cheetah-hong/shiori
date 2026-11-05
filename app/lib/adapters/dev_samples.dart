import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shiori_core/shiori_core.dart';

/// DEVELOPMENT ONLY: the `dev` flavor.
///
/// `assets/dev_samples/` holds the OCR passes of synthetic pages (made-up words
/// laid out like the textbook, `tools/synthetic/make_pages.py`) so the whole
/// flow runs on a simulator without a camera. Only the dev flavor bundles them
/// (pubspec.yaml), and the dev flavor never builds for release
/// (docs/architecture.md, 5).
const String devFlavor = 'dev';

/// Whether the sample pages are on for [flavor]: only in [devFlavor]. No
/// flavor, or any other, means off, whatever the build mode.
bool devSamplesEnabledFor(String? flavor) => flavor == devFlavor;

/// The samples switch for this build (`flutter run --flavor dev`, or no
/// `--flavor`: pubspec.yaml makes dev the default).
const bool devSamplesEnabled = appFlavor == devFlavor;

const String devSampleDir = 'assets/dev_samples';

final class DevSample {
  const DevSample({
    required this.id,
    required this.page,
    required this.detail,
    required this.layout,
  });

  /// Fixture name: `s140` → `s140.ja.json` + `s140.ko.json`.
  final String id;
  final int page;
  final String detail;
  final String layout;

  PageImage get image => PageImage(id, label: '샘플 $page쪽');
}

const List<DevSample> devSamples = [
  DevSample(id: 's010', page: 10, detail: 'DAY 01 자연, 몸', layout: '목록형'),
  DevSample(id: 's011', page: 11, detail: 'DAY 01 자연, 몸', layout: '목록형'),
  DevSample(id: 's140', page: 140, detail: 'DAY 20 여행·교통', layout: '항목형 · 예문'),
  DevSample(id: 's147', page: 147, detail: 'DAY 21 쇼핑', layout: '항목형 · 예문'),
];

/// Replays a sample page through the same pipeline as a real photo; refuses
/// every page when [enabled] is false.
TextRecognizer devSampleRecognizer(
  AssetBundle bundle, {
  bool enabled = devSamplesEnabled,
}) {
  if (!enabled) {
    return const _DisabledRecognizer();
  }
  return FixtureTextRecognizer((name) async {
    try {
      return await bundle.loadString('$devSampleDir/$name');
    } on FlutterError catch (e) {
      // AssetBundle reports a missing asset as an Error; the port expects an
      // Exception the capture screen can show.
      throw TextRecognitionException('샘플 페이지($name)가 없습니다', cause: e);
    }
  }, id: 'dev-sample');
}

final class _DisabledRecognizer implements TextRecognizer {
  const _DisabledRecognizer();

  @override
  String get id => 'dev-sample-disabled';

  @override
  Future<OcrScan> recognize(PageImage image) =>
      Future.error(const TextRecognitionException('이 빌드에는 샘플 페이지가 없습니다'));
}
