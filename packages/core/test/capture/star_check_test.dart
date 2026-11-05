// ★ cells on the photo: where they are, which rows get one, and how measured
// red shares turn into ★ marks.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/capture/scan_preparation.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Returns 0.01 for the cells of [starred] word numbers and 0 elsewhere,
/// and records every call.
final class _FakeMeter implements StarMeter {
  _FakeMeter(this.starred);

  final Set<String> starred;
  final calls = <List<StarCell>>[];

  @override
  String get id => 'fake';

  @override
  Future<StarMeasurement?> measure(
    PageImage image, {
    required List<StarCell> cells,
    required StarColor color,
    int turned = 0,
  }) async {
    calls.add(cells);
    return StarMeasurement([
      for (final c in cells) starred.contains(c.no) ? 0.01 : 0.0,
    ]);
  }
}

Future<(CaptureDraft, OcrScan)> _read(FixtureSet set, String fixture) async {
  final scan = await set.loadScan(fixture);
  return (await standardPipeline().fromScan(scan), scan);
}

void main() {
  final listColor = starColorFor('vocab.list')!;

  group('★ colour per template', () {
    test('the list layout starts from red ink and a 0.002 share', () {
      expect(listColor.minRed, 120);
      expect(listColor.minRedLead, 45);
      expect(listColor.minShare, 0.002);
    });

    test('entry pages and unknown templates are not checked', () {
      expect(starColorFor('vocab.entry'), isNull);
      expect(starColorFor('vocab.other'), isNull);
    });
  });

  group('cell positions (synthetic s011, Vision)', () {
    late CaptureDraft draft;
    late List<StarCell> cells;
    late List<OcrLine> stars;

    setUpAll(() async {
      final (d, scan) = await _read(synthetic, 's011');
      draft = d;
      cells = starCells(draft, scan, onlyUnmarked: false);
      // The printed ★ lines of 0015, 0019 and 0020 (x = number x + 0.187),
      // not the legend line at the top of the page.
      stars = [
        for (final l in scan.japanese.lines)
          if (l.text.trim() == '★') l,
      ]..sort((a, b) => a.y.compareTo(b.y));
    });

    test('one cell per entry, in entry order', () {
      expect(stars, hasLength(3));
      expect(cells.map((c) => c.entryIndex), [
        for (var i = 0; i < draft.entries.length; i++) i,
      ]);
      expect(cells.map((c) => c.no), draft.entries.map((e) => e.no));
    });

    test('each ★ is inside the cell of its own row and of no other row', () {
      for (final (star, no) in [
        (stars[0], '0015'),
        (stars[1], '0019'),
        (stars[2], '0020'),
      ]) {
        final cx = star.x + star.width / 2;
        final cy = star.cy;
        final holding = [
          for (final c in cells)
            if (c.contains(cx, cy)) c.no,
        ];
        expect(holding, [no], reason: '★ at $cx,$cy');
      }
    });

    test('cells stay on the page (0..1) and have an area', () {
      for (final c in cells) {
        expect(c.x, inInclusiveRange(0, 1));
        expect(c.y, inInclusiveRange(0, 1));
        expect(c.x + c.width, inInclusiveRange(0, 1));
        expect(c.y + c.height, inInclusiveRange(0, 1));
        expect(c.width, greaterThan(0));
        expect(c.height, greaterThan(0));
      }
    });
  });

  group('which rows get a cell', () {
    test('ML Kit list page: only rows without ★, 0013 among them', () async {
      final (draft, scan) = await _read(syntheticMlKit, 'm011');
      final cells = starCells(draft, scan);
      final unmarked = [
        for (final e in draft.entries)
          if (!e.important) e.no,
      ];
      expect(cells.map((c) => c.no), unmarked);
      expect(unmarked, contains('0013'));
      for (final no in ['0015', '0019', '0020']) {
        expect(unmarked, isNot(contains(no)), reason: '$no read with ★');
      }
      for (final c in cells) {
        expect(draft.entries[c.entryIndex].important, isFalse);
      }
    });

    test('entry pages get no cells', () async {
      for (final (set, fixture) in [
        (syntheticMlKit, 'm140'),
        (synthetic, 's140'),
      ]) {
        final (draft, scan) = await _read(set, fixture);
        expect(draft.templateId, 'vocab.entry');
        expect(starCells(draft, scan), isEmpty, reason: fixture);
        expect(starCells(draft, scan, onlyUnmarked: false), isEmpty);
      }
    });

    test('a template without a ★ setting gets no cells', () async {
      final (draft, scan) = await _read(syntheticMlKit, 'm011');
      final other = CaptureDraft(
        templateId: 'vocab.other',
        meta: draft.meta,
        entries: draft.entries,
      );
      expect(starCells(other, scan), isEmpty);
    });
  });

  group('applying measured shares', () {
    late CaptureDraft draft;
    late OcrScan scan;
    late List<StarCell> cells;

    setUpAll(() async {
      (draft, scan) = await _read(syntheticMlKit, 'm011');
      cells = starCells(draft, scan);
    });

    List<double> shares(double for0013) => [
      for (final c in cells) c.no == '0013' ? for0013 : 0.0,
    ];

    test('only the row over the threshold becomes ★, marked as inferred', () {
      final out = applyStarRatios(draft, cells, shares(0.01), listColor);
      final i = draft.entries.indexWhere((e) => e.no == '0013');
      expect(out.entries[i].important, isTrue);
      expect(out.entries[i].issues.map((x) => x.code), [
        ...draft.entries[i].issues.map((x) => x.code),
        'important:inferred',
      ]);
      expect(
        out.entries[i].statusOf(EntryField.important),
        FieldStatus.inferred,
      );
      for (var j = 0; j < draft.entries.length; j++) {
        if (j != i) expect(out.entries[j], draft.entries[j]);
      }
      expect(out.templateId, draft.templateId);
      expect(out.meta, draft.meta);
      expect(out.recognitionTime, draft.recognitionTime);
    });

    test('a share equal to the threshold is a ★; just below is not', () {
      final i = draft.entries.indexWhere((e) => e.no == '0013');
      expect(
        applyStarRatios(
          draft,
          cells,
          shares(0.002),
          listColor,
        ).entries[i].important,
        isTrue,
      );
      expect(
        applyStarRatios(
          draft,
          cells,
          shares(0.0019999),
          listColor,
        ).entries[i].important,
        isFalse,
      );
    });

    test('a wrong number of shares or none leaves the page as it is', () {
      expect(applyStarRatios(draft, cells, null, listColor), draft);
      expect(
        applyStarRatios(draft, cells, [...shares(0.01), 0.01], listColor),
        draft,
      );
      expect(
        applyStarRatios(draft, cells, shares(0.01).sublist(1), listColor),
        draft,
      );
    });

    test('the default block measures nothing: the page stays', () async {
      final out = await checkStars(
        draft: draft,
        scan: scan,
        image: const PageImage('m011'),
        meter: const NoStarMeter(),
      );
      expect(out, draft);
    });

    test('checkStars measures the cells with the template colour', () async {
      final meter = _FakeMeter({'0013'});
      final out = await checkStars(
        draft: draft,
        scan: scan,
        image: const PageImage('m011'),
        meter: meter,
      );
      expect(meter.calls, hasLength(1));
      expect(meter.calls.single.map((c) => c.no), cells.map((c) => c.no));
      expect(out.entries.where((e) => e.important).map((e) => e.no), [
        '0013',
        '0015',
        '0019',
        '0020',
      ]);
    });

    test('Vision pages are not measured (no call)', () async {
      final (visionDraft, visionScan) = await _read(synthetic, 's011');
      final meter = _FakeMeter({'0013'});
      final out = await checkStars(
        draft: visionDraft,
        scan: visionScan,
        image: const PageImage('s011'),
        meter: meter,
      );
      expect(meter.calls, isEmpty);
      expect(out, visionDraft);
    });

    test('entry pages are not measured (no call)', () async {
      final (entryDraft, entryScan) = await _read(syntheticMlKit, 'm140');
      final meter = _FakeMeter({'1215'});
      final out = await checkStars(
        draft: entryDraft,
        scan: entryScan,
        image: const PageImage('m140'),
        meter: meter,
      );
      expect(meter.calls, isEmpty);
      expect(out, entryDraft);
    });
  });

  group('score with the ★ check (synthetic pages, ML Kit)', () {
    Future<CaptureScore> score(StarMeter? meter) => scoreCapture(
      truth: syntheticMlKit.truth,
      loadScan: syntheticMlKit.loadScan,
      pipeline: standardPipeline(),
      refine: meter == null
          ? null
          : (draft, scan, fixture) => checkStars(
              draft: draft,
              scan: scan,
              image: PageImage(fixture),
              meter: meter,
            ),
    );

    test(
      '0013 comes back: ★ 17/18, rows 15/18 (1215 is an entry page)',
      () async {
        final s = await score(_FakeMeter({'0013'}));
        expect(s.total('important'), (ok: 17, of: 18));
        expect(s.total('row'), (ok: 15, of: 18));
        expect(s.total('found'), (ok: 18, of: 18));
      },
    );

    test('without a block the score stays (★ 16/18, rows 14/18)', () async {
      for (final meter in [null, const NoStarMeter()]) {
        final s = await score(meter);
        expect(s.total('important'), (ok: 16, of: 18));
        expect(s.total('row'), (ok: 14, of: 18));
      }
    });
  });

  group('OcrScan.turned', () {
    Map<String, Object?> page() => {'engine': 'mlkit', 'lines': <Object>[]};

    test('read from the channel payload', () {
      final scan = OcrScan.fromJson({'ja': page(), 'ko': page(), 'turned': 90});
      expect(scan.turned, 90);
    });

    test('0 when the payload has none', () {
      expect(OcrScan.fromJson({'ja': page(), 'ko': page()}).turned, 0);
    });

    test('kept through line clean-up and JSON', () {
      final scan = OcrScan.fromJson({
        'ja': page(),
        'ko': page(),
        'turned': 270,
      });
      expect(prepareScan(scan).turned, 270);
      expect(OcrScan.fromJson(scan.toJson()).turned, 270);
    });
  });
}
