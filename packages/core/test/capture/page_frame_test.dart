// The parser reads a page the same way whatever the image frame: the whole
// photo, a scanner crop of the page or a closer photo (column positions are
// measured from the content), and it survives the OCR slips that used to break
// whole pages (a lone number in the meaning column, a symbol glued to the
// reading).
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/capture/scan_preparation.dart';
import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/capture/vocab/column_scale.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

OcrLine _moved(OcrLine l, OcrLine Function(OcrLine) f) => f(l);

/// The page as a scanner would return it: the part [x0]..[x0]+[w] (and
/// [y0]..[y0]+[h]) of the photo stretched to the whole image.
OcrScan cropped(
  OcrScan s, {
  double x0 = 0,
  double y0 = 0,
  double w = 1,
  double h = 1,
}) {
  OcrLine crop(OcrLine l) => OcrLine(
    text: l.text,
    confidence: l.confidence,
    x: (l.x - x0) / w,
    y: (l.y - y0) / h,
    width: l.width / w,
    height: l.height / h,
  );
  OcrPage page(OcrPage p) =>
      p.withLines([for (final l in p.lines) _moved(l, crop)]);
  return OcrScan(japanese: page(s.japanese), korean: page(s.korean));
}

OcrScan withJapanese(OcrScan s, List<OcrLine> Function(List<OcrLine>) edit) =>
    OcrScan(
      japanese: s.japanese.withLines(edit(s.japanese.lines)),
      korean: s.korean,
    );

String _describe(CaptureDraft d) => [
  d.templateId,
  for (final e in d.entries)
    '${e.no} ${e.headword}|${e.readings.join('/')}|${e.pos?.badge}|'
        '${e.meaning}|${e.example}|${e.issues.map((i) => i.code)}',
].join('\n');

void main() {
  final pipeline = standardPipeline();

  group('same entries in any image frame', () {
    for (final fixture in ['s010', 's011', 's140', 's147']) {
      for (final (label, x0, y0, w, h) in [
        ('page crop (0.72 × 0.9 of the photo)', 0.14, 0.04, 0.72, 0.9),
        ('closer photo (0.85 × 0.95)', 0.08, 0.02, 0.85, 0.95),
        ('wider photo (1.2 × 1.05)', -0.1, -0.02, 1.2, 1.05),
      ]) {
        test('$fixture, $label', () async {
          final scan = await loadScan(fixture);
          final photo = await pipeline.fromScan(scan);
          final page = await pipeline.fromScan(
            cropped(scan, x0: x0, y0: y0, w: w, h: h),
          );
          expect(_describe(page), _describe(photo));
          // The page meta is read from text, not positions, except the page
          // line fallback (s010), which needs the bottom of the image.
          if (fixture != 's010') expect(page.meta, photo.meta);
        });
      }
    }
  });

  group('page-breaking OCR slips', () {
    test(
      'a meaning line misread as four digits does not split the page',
      () async {
        final scan = await loadScan('s011');
        final before = await pipeline.fromScan(scan);
        // Japanese pass reads one meaning cell (x ≈ ax + 0.39) as a number.
        final slipped = withJapanese(
          scan,
          (ja) => [
            ...ja,
            const OcrLine(
              text: '2010 年',
              x: 0.60,
              y: 0.40,
              width: 0.03,
              height: 0.009,
            ),
          ],
        );
        final after = await pipeline.fromScan(slipped);
        expect(_describe(after), _describe(before));
      },
    );

    test('a short column of numbers with checkboxes is still a page', () async {
      final anchors = [
        const OcrLine(
          text: '0013 ロロロ',
          x: 0.05,
          y: 0.2,
          width: 0.04,
          height: 0.008,
        ),
        const OcrLine(
          text: '0014',
          x: 0.05,
          y: 0.25,
          width: 0.02,
          height: 0.008,
        ),
        for (var k = 0; k < 5; k++)
          OcrLine(
            text: '00${30 + k}',
            x: 0.55,
            y: 0.2 + 0.05 * k,
            width: 0.02,
            height: 0.008,
          ),
      ];
      final scan = OcrScan(
        japanese: OcrPage(lines: anchors),
        korean: const OcrPage(lines: []),
      );
      // No reading column: no entries, but both columns stay anchors, so the
      // left page keeps its right edge at the right page's numbers.
      final draft = await pipeline.fromScan(scan);
      expect(draft.templateId, 'vocab.list');
    });

    test('a ★ glued to the reading is dropped like a lone one', () async {
      final scan = await loadScan('s011');
      final before = await pipeline.fromScan(scan);
      // Join the ★ line and the reading line of 0015 into one `★かわ` line.
      final glued = withJapanese(scan, (ja) {
        final star = ja.singleWhere(
          (l) => l.text == '★' && (l.cy - 0.28).abs() < 0.03,
        );
        final reading = ja.singleWhere((l) => l.text == 'かわ');
        return [
          for (final l in ja)
            if (!identical(l, star) && !identical(l, reading)) l,
          OcrLine(
            text: '★かわ',
            x: star.x,
            y: reading.y,
            width: reading.x + reading.width - star.x,
            height: reading.height,
          ),
        ];
      });
      final after = await pipeline.fromScan(glued);
      final got = after.entries.singleWhere((e) => e.no == '0015');
      expect(got.readings, ['かわ']);
      expect(_describe(after), _describe(before));
    });
  });

  group('columnScale', () {
    Future<double> scaleOf(OcrScan s, {bool readings = true}) async {
      final ja = [
        for (final l in s.japanese.lines)
          if (readings || !isReadingCell(l.text) || l.text == 'ロロロ') l,
      ];
      return columnScale(
        anchors: findAnchors(ja),
        ja: ja,
        ko: s.korean.lines,
        shape: listRow,
      ).value;
    }

    test('is about 1 on the photo and 1/0.72 on a page crop', () async {
      final scan = await loadScan('s011');
      expect(await scaleOf(scan), closeTo(0.96, 0.03));
      final crop = cropped(scan, x0: 0.14, w: 0.72);
      expect(
        await scaleOf(crop) / await scaleOf(scan),
        closeTo(1 / 0.72, 1e-6),
      );
    });

    test('falls back to the POS badge column without readings', () async {
      final scan = await loadScan('s011');
      // Cropped in both directions: the skewed rows climb further per column.
      final crop = cropped(scan, x0: 0.14, y0: 0.1, w: 0.72, h: 0.72);
      final photo = await scaleOf(scan, readings: false);
      expect(photo, closeTo(0.96, 0.05));
      expect(
        await scaleOf(crop, readings: false) / photo,
        closeTo(1 / 0.72, 1e-6),
      );
    });

    test('is 1 when too few rows were read to tell', () async {
      expect(
        columnScale(
          anchors: findAnchors([
            const OcrLine(
              text: '0013',
              x: 0.2,
              y: 0.2,
              width: 0.02,
              height: 0.008,
            ),
          ]),
          ja: const [],
          ko: const [],
          shape: entryRow,
        ).value,
        1.0,
      );
    });
  });

  group('prepareScan', () {
    OcrLine l(String t, {double x = 0.1, double c = 1.0}) =>
        OcrLine(text: t, confidence: c, x: x, y: 0.5, width: 0.1, height: 0.02);

    test('cuts a glued symbol out by character count and drops it', () {
      final out = dropSymbolNoise([l('乗り換える*のりかえる')]);
      expect(out.map((o) => o.text), ['乗り換える', 'のりかえる']);
      expect(out[0].x, closeTo(0.1, 1e-9));
      expect(out[0].width, closeTo(5 * 0.1 / 11, 1e-9));
      expect(out[1].x, closeTo(0.1 + 6 * 0.1 / 11, 1e-9));
      expect(out[1].width, closeTo(5 * 0.1 / 11, 1e-9));
    });

    test('drops lone ★ ☆ * ＊; plain lines stay as they are', () {
      final plain = l('かわ');
      final out = dropSymbolNoise([
        l(' * '),
        l('☆'),
        l('★'),
        l('＊'),
        l('★ ☆'),
        plain,
      ]);
      expect(out.map((o) => o.text), ['かわ']);
      expect(identical(out.single, plain), isTrue);
    });

    test('the legend line keeps its text without the symbol', () {
      expect(dropSymbolNoise([l('★三人=試験')]).map((o) => o.text), ['三人=試験']);
    });

    test('drops low-confidence ML Kit lines and lone symbols', () {
      final scan = OcrScan(
        japanese: OcrPage(
          engine: mlKitEngine,
          lines: [
            l('問大', c: 0.1),
            l('★', c: 0.05),
            l('*', c: 0.9),
            l('かわ', c: 0.7),
          ],
        ),
        korean: OcrPage(
          engine: mlKitEngine,
          lines: [l('강', c: 0.6), l('xx', c: 0.1)],
        ),
      );
      final out = prepareScan(scan);
      expect(out.japanese.lines.map((o) => o.text), ['かわ']);
      expect(out.korean.lines.map((o) => o.text), ['강']);
    });

    test('keeps every Vision line whatever its confidence', () {
      final scan = OcrScan(
        japanese: OcrPage(engine: appleVisionEngine, lines: [l('問大', c: 0.3)]),
        korean: OcrPage(engine: appleVisionEngine, lines: [l('강', c: 0.3)]),
      );
      final out = prepareScan(scan);
      expect(out.japanese.lines, hasLength(1));
      expect(out.korean.lines, hasLength(1));
    });

    test('is idempotent', () {
      final scan = OcrScan(
        japanese: OcrPage(lines: [l('川 ★かわ'), l('*')]),
        korean: const OcrPage(lines: []),
      );
      final once = prepareScan(scan);
      final twice = prepareScan(once);
      expect(
        twice.japanese.lines.map((o) => (o.text, o.x, o.width)),
        once.japanese.lines.map((o) => (o.text, o.x, o.width)),
      );
      expect(once.japanese.lines.map((o) => o.text), ['川', 'かわ']);
    });
  });
}
