import 'dart:convert';

import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/models/page_image.dart';
import 'package:shiori_core/src/ports/text_recognizer.dart';

/// Replays recorded OCR passes instead of reading a photo.
///
/// `recognize(PageImage('s140'))` loads `s140.ja.json` and `s140.ko.json`
/// through [loadText] (a file reader in tests, the asset bundle in the app).
final class FixtureTextRecognizer implements TextRecognizer {
  const FixtureTextRecognizer(this.loadText, {this.id = 'fixture'});

  final Future<String> Function(String fileName) loadText;

  @override
  final String id;

  @override
  Future<OcrScan> recognize(PageImage image) async {
    try {
      // Awaited one by one: Future.wait loses values from SynchronousFuture
      // loaders (Flutter's asset bundle returns those for cached assets).
      final ja = await loadText('${image.path}.ja.json');
      final ko = await loadText('${image.path}.ko.json');
      return OcrScan(japanese: _page(ja), korean: _page(ko));
    } on FormatException catch (e) {
      throw TextRecognitionException(
        '녹화된 판독 결과(${image.path})의 형식이 올바르지 않습니다',
        cause: e,
      );
    } on Exception catch (e) {
      throw TextRecognitionException(
        '녹화된 판독 결과(${image.path})를 읽지 못했습니다',
        cause: e,
      );
    }
  }

  static OcrPage _page(String text) {
    final json = jsonDecode(text);
    if (json is! Map) {
      throw const FormatException('OCR fixture must be a JSON object');
    }
    return OcrPage.fromJson(json.cast<String, Object?>());
  }
}
