import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// Korean name of a cell, for labels and screen readers.
String fieldLabel(EntryField field) => switch (field) {
  EntryField.headword => '표제어',
  EntryField.readings => '읽기',
  EntryField.meaning => '뜻',
  EntryField.pos => '품사',
  EntryField.example => '예문',
};

/// The page the evidence boxes are on: the photo, or the OCR passes drawn
/// as a page when there is no photo (sample pages).
final class EvidencePage {
  const EvidencePage({this.photo, this.scan});

  final Uint8List? photo;
  final OcrScan? scan;

  bool get isEmpty => photo == null && scan == null;
}

/// Opens 근거 조각 for [field] of [entry]: the piece of the page each value
/// was read from (or, for a dictionary value, the headword's piece).
Future<void> showEvidence(
  BuildContext context, {
  required CapturedEntry entry,
  required EntryField field,
  required EvidencePage page,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => EvidenceScreen(entry: entry, field: field, page: page),
  ),
);

/// 근거 조각: the cell's value, where it came from, and the photo pieces.
class EvidenceScreen extends StatelessWidget {
  const EvidenceScreen({
    super.key,
    required this.entry,
    required this.field,
    required this.page,
  });

  final CapturedEntry entry;
  final EntryField field;
  final EvidencePage page;

  String get _value => switch (field) {
    EntryField.headword => entry.headword,
    EntryField.readings => entry.readings.join(' / '),
    EntryField.meaning => entry.meaning,
    EntryField.example => entry.example?.ja ?? '',
    EntryField.pos => entry.pos?.label ?? '',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cell = entry.evidence?.of(field);
    final own = [
      for (final b in cell?.boxes ?? const <PhotoBox>[])
        if (!b.clamped().isEmpty) b.clamped(),
    ];
    // A dictionary value has no piece of its own: show the headword's.
    final pieces = own.isNotEmpty
        ? own
        : [
            for (final b
                in entry.evidence?.of(EntryField.headword)?.boxes ??
                    const <PhotoBox>[])
              if (!b.clamped().isEmpty) b.clamped(),
          ];
    return Scaffold(
      appBar: AppBar(title: const Text('근거 조각')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.sm,
          Space.gutter,
          Space.section,
        ),
        children: [
          Text(
            '${entry.headword.isEmpty ? '(표제어 없음)' : entry.headword} · '
            '${fieldLabel(field)}',
            style: context.text.titleLarge,
          ),
          const SizedBox(height: Space.xs),
          JpText(
            _value.isEmpty ? '(비어 있음)' : _value,
            style: JpType.print(22, t.text),
          ),
          const SizedBox(height: Space.sm),
          Text(
            [
              '출처: ${cell?.source.label ?? '사진'}',
              if (cell?.confidence case final c?) '짝 신뢰도 ${c.label}',
              ?cell?.note,
            ].join(' · '),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.lg),
          if (page.isEmpty || pieces.isEmpty)
            Text(
              own.isEmpty && cell?.source == FieldSource.dictionary
                  ? '사전에서 가져온 값이라 사진에 근거 조각이 없어요.'
                  : '이 칸의 근거 조각을 보여 줄 사진이 없어요.',
              style: context.text.bodyMedium,
            )
          else ...[
            if (own.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  '사전에서 가져온 값이에요. 아래는 표제어가 찍힌 자리예요.',
                  style: context.text.bodySmall,
                ),
              ),
            for (final box in pieces)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: EvidenceCrop(page: page, box: box),
              ),
            if (page.photo == null)
              Text('사진이 없어 판독 기록으로 그린 쪽입니다.', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// How much page to show around a box: this many box heights above and
/// below, and at least this share of the page width (the line around it).
const double _marginLines = 2.5;
const double _minRegionWidth = 0.5;

/// The largest side a photo is decoded to for the evidence view.
const int _maxDecodedSide = 2048;

/// Width / height of a page drawn from OCR text (no photo): A-series paper.
const double _drawnPageAspect = 1 / math.sqrt2;

/// The region of the page around [box] that a crop shows (normalized).
@visibleForTesting
Rect cropRegion(PhotoBox box) {
  final b = box.clamped();
  final dx = math.max(b.width * 0.3, (_minRegionWidth - b.width) / 2);
  final dy = b.height * _marginLines;
  return Rect.fromLTRB(
    (b.x - dx).clamp(0.0, 1.0),
    (b.y - dy).clamp(0.0, 1.0),
    (b.right + dx).clamp(0.0, 1.0),
    (b.bottom + dy).clamp(0.0, 1.0),
  );
}

/// One piece of the page around [box], the box outlined.
class EvidenceCrop extends StatefulWidget {
  const EvidenceCrop({super.key, required this.page, required this.box});

  final EvidencePage page;
  final PhotoBox box;

  @override
  State<EvidenceCrop> createState() => _EvidenceCropState();
}

class _EvidenceCropState extends State<EvidenceCrop> {
  Future<ui.Image?>? _image;

  @override
  void initState() {
    super.initState();
    final photo = widget.page.photo;
    if (photo != null) _image = _decode(photo);
  }

  @override
  void dispose() {
    unawaited(_image?.then((i) => i?.dispose()));
    super.dispose();
  }

  /// The photo decoded at most [_maxDecodedSide] wide or high; null when
  /// the bytes are not an image the engine can read.
  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        _maxDecodedSide / math.max(descriptor.width, descriptor.height),
      );
      // Only the width: the codec keeps the aspect (and any orientation the
      // file carries).
      final codec = await descriptor.instantiateCodec(
        targetWidth: scale < 1 ? (descriptor.width * scale).round() : null,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      return frame.image;
    } on Exception catch (e) {
      debugPrint('evidence photo: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final region = cropRegion(widget.box);
    final turned = widget.page.scan?.turned ?? 0;
    Widget frame(Widget child, double aspect) => Semantics(
      label: '근거 조각',
      image: true,
      child: ClipRRect(
        key: const ValueKey('evidence-crop'),
        borderRadius: BorderRadius.circular(Radii.tile),
        child: AspectRatio(
          aspectRatio: aspect.isFinite && aspect > 0 ? aspect : 4,
          child: ColoredBox(color: t.surface, child: child),
        ),
      ),
    );
    final image = _image;
    if (image == null) {
      final aspect =
          region.width * _drawnPageAspect / math.max(region.height, 1e-6);
      return frame(
        CustomPaint(
          painter: _DrawnPagePainter(
            scan: widget.page.scan,
            region: region,
            box: widget.box.clamped(),
            textColor: t.text,
            mark: t.accent,
          ),
        ),
        aspect,
      );
    }
    return FutureBuilder<ui.Image?>(
      future: image,
      builder: (context, snap) {
        final img = snap.data;
        if (img == null) {
          return frame(
            Center(
              child: snap.connectionState == ConnectionState.done
                  ? Text('사진을 열 수 없어요', style: context.text.bodySmall)
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
            4,
          );
        }
        final sideways = turned % 180 != 0;
        final w = (sideways ? img.height : img.width).toDouble();
        final h = (sideways ? img.width : img.height).toDouble();
        return frame(
          CustomPaint(
            painter: _PhotoPainter(
              image: img,
              turned: turned,
              region: region,
              box: widget.box.clamped(),
              mark: t.accent,
            ),
          ),
          region.width * w / math.max(region.height * h, 1e-6),
        );
      },
    );
  }
}

/// The photo turned upright (the OCR channel turned it [turned] degrees
/// clockwise), cut to [region], with [box] outlined.
class _PhotoPainter extends CustomPainter {
  _PhotoPainter({
    required this.image,
    required this.turned,
    required this.region,
    required this.box,
    required this.mark,
  });

  final ui.Image image;
  final int turned;
  final Rect region;
  final PhotoBox box;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final sideways = turned % 180 != 0;
    final w = (sideways ? image.height : image.width).toDouble();
    final h = (sideways ? image.width : image.height).toDouble();
    final sx = size.width / (region.width * w);
    final sy = size.height / (region.height * h);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..scale(sx, sy)
      ..translate(-region.left * w, -region.top * h);
    // Upright frame: rotate the decoded photo the way the channel did.
    switch (turned % 360) {
      case 90:
        canvas
          ..translate(w, 0)
          ..rotate(math.pi / 2);
      case 180:
        canvas
          ..translate(w, h)
          ..rotate(math.pi);
      case 270:
        canvas
          ..translate(0, h)
          ..rotate(-math.pi / 2);
    }
    canvas
      ..drawImage(
        image,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
    _outline(canvas, size, region, box, mark);
  }

  @override
  bool shouldRepaint(_PhotoPainter old) =>
      old.image != image ||
      old.turned != turned ||
      old.region != region ||
      old.box != box;
}

/// The OCR text drawn where it was read, cut to [region] (no photo).
class _DrawnPagePainter extends CustomPainter {
  _DrawnPagePainter({
    required this.scan,
    required this.region,
    required this.box,
    required this.textColor,
    required this.mark,
  });

  final OcrScan? scan;
  final Rect region;
  final PhotoBox box;
  final Color textColor;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final s = scan;
    if (s != null) {
      final ja = [
        for (final l in s.japanese.lines)
          if (l.confidence > lowestOcrConfidence + 1e-6) l,
      ];
      final ko = [
        for (final l in s.korean.lines)
          if (l.confidence > lowestOcrConfidence + 1e-6 &&
              !ja.any((j) => _overlap(j, l)))
            l,
      ];
      for (final l in [...ko, ...ja]) {
        _drawLine(canvas, size, l);
      }
    }
    canvas.restore();
    _outline(canvas, size, region, box, mark);
  }

  void _drawLine(Canvas canvas, Size size, OcrLine l) {
    final r = _toCanvas(
      size,
      region,
      PhotoBox(x: l.x, y: l.y, width: l.width, height: l.height).clamped(),
    );
    if (r.isEmpty || !r.overlaps(Offset.zero & size)) return;
    // Set at the box's height, squeezed to its width when wider.
    final painter = TextPainter(
      text: TextSpan(
        text: l.text,
        style: TextStyle(
          color: textColor,
          fontSize: math.max(r.height * 0.85, 4),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final squeeze = painter.width > r.width && painter.width > 0
        ? r.width / painter.width
        : 1.0;
    canvas
      ..save()
      ..translate(r.left, r.top + (r.height - painter.height) / 2)
      ..scale(squeeze, 1);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
    painter.dispose();
  }

  static bool _overlap(OcrLine a, OcrLine b) {
    final w = math.min(a.x + a.width, b.x + b.width) - math.max(a.x, b.x);
    final h = math.min(a.y + a.height, b.y + b.height) - math.max(a.y, b.y);
    return w > 0 && h > 0.5 * math.min(a.height, b.height);
  }

  @override
  bool shouldRepaint(_DrawnPagePainter old) =>
      old.scan != scan || old.region != region || old.box != box;
}

Rect _toCanvas(Size size, Rect region, PhotoBox b) => Rect.fromLTWH(
  (b.x - region.left) / region.width * size.width,
  (b.y - region.top) / region.height * size.height,
  b.width / region.width * size.width,
  b.height / region.height * size.height,
);

void _outline(Canvas canvas, Size size, Rect region, PhotoBox box, Color c) {
  if (box.isEmpty || region.width <= 0 || region.height <= 0) return;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      _toCanvas(size, region, box).inflate(2),
      const Radius.circular(4),
    ),
    Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
}
