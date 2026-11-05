import 'package:shiori_core/src/models/ocr.dart';
import 'package:shiori_core/src/models/page_image.dart';

/// Block slot: reads the text on a page photo.
///
/// First blocks: Apple Vision (iOS channel), ML Kit (Android channel),
/// `FixtureTextRecognizer` (recorded JSON). Next: Cloud Vision, Claude.
abstract interface class TextRecognizer {
  /// Short id for logs and the review screen, for example `apple-vision`.
  String get id;

  /// Reads [image] twice (Japanese-first and Korean-first).
  ///
  /// Throws [TextRecognitionException] when the page cannot be read.
  Future<OcrScan> recognize(PageImage image);
}

final class TextRecognitionException implements Exception {
  const TextRecognitionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'TextRecognitionException: $message${cause == null ? '' : ' ($cause)'}';
}
