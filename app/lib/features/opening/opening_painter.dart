import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/opening/opening_timeline.dart';
import 'package:shiori/shared/shi_stroke.dart';
import 'package:shiori/shared/svg_path.dart';

// The page (the launch screen's picture), on the markCanvas.
const _page = Rect.fromLTWH(336, 300, 352, 424);
const _pageRadius = Radius.circular(30);
const _pageBorder = 14.0;
const _headword = Rect.fromLTWH(392, 392, 170, 36);
const _point = Rect.fromLTWH(392, 476, 200, 26);
const _rule = Rect.fromLTWH(392, 540, 140, 26);

// The camera corners.
const _corners = [
  'M196 330 V196 H330',
  'M694 196 H828 V330',
  'M828 694 V828 H694',
  'M330 828 H196 V694',
];
const _cornerWidth = 40.0;
const _center = Offset(markCanvas / 2, markCanvas / 2);

/// Draws the opening at [progress] (0–1 of [openingLength]) on a square.
class OpeningPainter extends CustomPainter {
  OpeningPainter({required this.progress, required this.tokens})
    : super(repaint: progress);

  final Animation<double> progress;
  final ShioriTokens tokens;

  static final _cornerPaths = [for (final d in _corners) parseSvgPath(d)];
  static final _shi = shiStrokePath(const Size(markCanvas, markCanvas));

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    canvas.save();
    canvas.scale(size.width / markCanvas, size.height / markCanvas);
    _paintBook(canvas, t);
    _paintCorners(canvas, t);
    _paintShi(canvas, t);
    canvas.restore();
  }

  void _paintBook(Canvas canvas, double t) {
    final opacity = track(bookOpacity, t);
    if (opacity <= 0) return;
    _scaled(canvas, track(bookScale, t), () {
      canvas.saveLayer(null, _layerPaint(opacity));
      final page = RRect.fromRectAndRadius(_page, _pageRadius);
      canvas.drawRRect(page, _fill(tokens.bg));
      canvas.drawRRect(page, _stroke(tokens.line, _pageBorder));
      _bar(canvas, _headword, tokens.text);
      _bar(canvas, _point, tokens.accent);
      _bar(canvas, _rule, tokens.line);
      canvas.restore();
    });
  }

  void _paintCorners(Canvas canvas, double t) {
    final opacity = track(frameOpacity, t);
    if (opacity <= 0) return;
    final paint = _stroke(
      tokens.accent.withValues(alpha: opacity),
      _cornerWidth,
    );
    _scaled(canvas, track(frameScale, t), () {
      for (final corner in _cornerPaths) {
        canvas.drawPath(corner, paint);
      }
    });
  }

  void _paintShi(Canvas canvas, double t) {
    final drawn = track(shiDrawn, t);
    if (drawn <= 0) return;
    final width = shiStrokeWidth * track(shiWeight, t);
    for (final metric in _shi.computeMetrics()) {
      final part = metric.extractPath(0, metric.length * drawn);
      canvas.drawPath(part, _stroke(tokens.accent, width));
    }
  }

  void _bar(Canvas canvas, Rect rect, Color color) => canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    _fill(color),
  );

  static void _scaled(Canvas canvas, double scale, VoidCallback draw) {
    canvas.save();
    canvas.translate(_center.dx, _center.dy);
    canvas.scale(scale);
    canvas.translate(-_center.dx, -_center.dy);
    draw();
    canvas.restore();
  }

  /// Only the alpha of a layer paint counts.
  Paint _layerPaint(double opacity) =>
      Paint()..color = tokens.text.withValues(alpha: opacity);

  static Paint _fill(Color color) => Paint()..color = color;

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(OpeningPainter old) =>
      old.progress != progress || old.tokens != tokens;
}
