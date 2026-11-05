import 'package:shiori_core/src/models/page_image.dart';

enum ImageOrigin { camera, gallery }

/// Block slot: where page photos come from.
///
/// First block: image_picker (camera and album). Next: a document scanner
/// (cunning_document_scanner), then page flattening.
abstract interface class ImageSource {
  /// Returns null when the learner cancels.
  Future<PageImage?> pick(ImageOrigin origin);

  /// Frees what [pick] left behind (a temporary photo file) once the page has
  /// been read. Never throws; a file that is already gone is fine.
  Future<void> discard(PageImage image);
}

/// A photo could not be taken or loaded. [message] is shown to the learner.
final class ImageSourceException implements Exception {
  const ImageSourceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ImageSourceException: $message';
}
