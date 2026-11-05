import 'package:shiori_core/src/models/page_image.dart';

/// Where a printed ★ would sit on one word row: a box on the upright page,
/// normalized to 0..1 like `OcrLine` (origin top-left).
final class StarCell {
  const StarCell({
    required this.entryIndex,
    required this.no,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Index of the entry in its `CaptureDraft`.
  final int entryIndex;

  /// The entry's word number (for logs and recorded measurements).
  final String? no;
  final double x;
  final double y;
  final double width;
  final double height;

  bool contains(double px, double py) =>
      x <= px && px <= x + width && y <= py && py <= y + height;

  Map<String, Object?> toJson() => {
    'no': no,
    'x': x,
    'y': y,
    'w': width,
    'h': height,
  };

  @override
  String toString() => 'StarCell($no @ $x,$y ${width}x$height)';
}

/// How a textbook prints its ★: a red pixel has `R > minRed` and
/// `R − max(G, B) > minRedLead`; a cell with at least [minShare] red pixels
/// holds a ★.
final class StarColor {
  const StarColor({
    required this.minRed,
    required this.minRedLead,
    required this.minShare,
  });

  final int minRed;
  final int minRedLead;
  final double minShare;

  /// What the pixel counter needs (the share is decided in Dart).
  Map<String, Object?> toJson() => {'minRed': minRed, 'minRedLead': minRedLead};
}

/// Red-pixel shares of the cells, in the order the cells were given.
final class StarMeasurement {
  StarMeasurement(List<double> ratios, {this.elapsed = Duration.zero})
    : ratios = List.unmodifiable(ratios);

  final List<double> ratios;
  final Duration elapsed;
}

/// Block slot: measures the ★ cells on the page photo.
///
/// First block: the Android channel (`measureStars`). ML Kit drops about one
/// ★ in three, and the photo still shows it.
abstract interface class StarMeter {
  /// Short id for logs, for example `android`.
  String get id;

  /// Shares for [cells] on [image], or null when the photo cannot be measured
  /// here (no channel, no file). [turned]: clockwise degrees the recognizer
  /// turned the page after its EXIF rotation (`OcrScan.turned`), so the cells
  /// are found in the same upright frame.
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  });
}

/// Measures nothing: the page keeps the ★ marks OCR read.
final class NoStarMeter implements StarMeter {
  const NoStarMeter();

  @override
  String get id => 'none';

  @override
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  }) async => null;
}
