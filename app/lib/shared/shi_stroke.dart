import 'dart:typed_data';
import 'dart:ui';

import 'package:shiori/shared/svg_path.dart';

/// The drawings of the app mark live on a 1024 × 1024 canvas, like the icon.
const double markCanvas = 1024;

/// The one 「し」 stroke shared by the icon and the opening. Swap this when
/// the icon's final stroke changes; everything that draws し follows.
const String shiStrokeSvg =
    'M448 372 V548 C448 650 522 680 574 640 C604 616 620 590 628 560';

/// Stroke width of し on the [markCanvas].
const double shiStrokeWidth = 58;

/// [shiStrokeSvg] scaled from the [markCanvas] to [size].
Path shiStrokePath(Size size) => scaledMarkPath(shiStrokeSvg, size);

/// Any mark path from the [markCanvas] scaled to [size].
Path scaledMarkPath(String svg, Size size) {
  final matrix = Float64List(16)
    ..[0] = size.width / markCanvas
    ..[5] = size.height / markCanvas
    ..[10] = 1
    ..[15] = 1;
  return parseSvgPath(svg).transform(matrix);
}
