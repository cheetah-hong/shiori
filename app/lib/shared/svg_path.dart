import 'dart:ui';

final _token = RegExp(r'[MLHVCZmlhvcz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?');

/// A [Path] from SVG path data in absolute commands (M L H V C Z), as the
/// drawings are written in the design files. Unknown commands throw so a
/// mistyped constant fails loudly instead of drawing half a shape.
Path parseSvgPath(String data) {
  final tokens = _token.allMatches(data).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  var command = '';
  var x = 0.0;
  var y = 0.0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[A-Za-z]$').hasMatch(tokens[i])) command = tokens[i++];
    switch (command) {
      case 'M':
        (x, y) = (next(), next());
        path.moveTo(x, y);
        command = 'L';
      case 'L':
        (x, y) = (next(), next());
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'C':
        final (x1, y1, x2, y2) = (next(), next(), next(), next());
        (x, y) = (next(), next());
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'Z':
        path.close();
      default:
        throw FormatException('Unsupported SVG path command "$command"', data);
    }
  }
  return path;
}
