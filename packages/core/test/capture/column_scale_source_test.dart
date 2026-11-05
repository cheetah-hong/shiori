// The column scale says how it was found, and the draft keeps it per page, so
// the review screen can say when the columns were read at the default frame.
// Synthetic pages and made-up lines only.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/capture/vocab/column_scale.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

OcrLine _line(String text, double x, double y) =>
    OcrLine(text: text, x: x, y: y, width: 0.06, height: 0.012);

/// Word numbers with their checkboxes, one per row, 0.05 apart.
List<OcrLine> _numbers(int count, {double x = 0.1}) => [
  for (var i = 0; i < count; i++)
    _line('${(i + 1).toString().padLeft(4, '0')} ロロロ', x, 0.2 + 0.05 * i),
];

void main() {
  group('how columnScale was found', () {
    ColumnScale scaleOf(OcrScan s, {bool readings = true}) {
      final ja = [
        for (final l in s.japanese.lines)
          if (readings || !isReadingCell(l.text) || l.text == 'ロロロ') l,
      ];
      return columnScale(
        anchors: findAnchors(ja),
        ja: ja,
        ko: s.korean.lines,
        shape: listRow,
      );
    }

    test('from the reading column on the photo', () async {
      final scale = scaleOf(await loadScan('s011'));
      expect(scale.source, ColumnScaleSource.reading);
      expect(scale.value, closeTo(0.96, 0.03));
      expect(scale.isDefault, isFalse);
    });

    test('from the POS badge column when no reading was read', () async {
      final scale = scaleOf(await loadScan('s011'), readings: false);
      expect(scale.source, ColumnScaleSource.badge);
      expect(scale.value, closeTo(0.96, 0.05));
      expect(scale.isDefault, isFalse);
    });

    test('the default 1.0 when a single number was read', () {
      final ja = _numbers(1);
      final scale = columnScale(
        anchors: findAnchors(ja),
        ja: ja,
        ko: const [],
        shape: entryRow,
      );
      expect(scale.value, 1.0);
      expect(scale.source, ColumnScaleSource.tooFewRows);
      expect(scale.isDefault, isTrue);
    });

    test('the default 1.0 when the reading column is twice as far as on the '
        'photo (beyond 1.8)', () {
      final ja = [
        ..._numbers(3),
        for (var i = 0; i < 3; i++)
          _line('あめ', 0.1 + 2 * listReadingOffset, 0.2 + 0.05 * i),
      ];
      final scale = columnScale(
        anchors: findAnchors(ja),
        ja: ja,
        ko: const [],
        shape: listRow,
      );
      expect(scale.value, 1.0);
      expect(scale.source, ColumnScaleSource.outOfRange);
      expect(scale.isDefault, isTrue);
    });

    test('the same reading column at 1.5 times the photo is measured', () {
      final ja = [
        ..._numbers(3),
        for (var i = 0; i < 3; i++)
          _line('あめ', 0.1 + 1.5 * listReadingOffset, 0.2 + 0.05 * i),
      ];
      final scale = columnScale(
        anchors: findAnchors(ja),
        ja: ja,
        ko: const [],
        shape: listRow,
      );
      expect(scale.value, closeTo(1.5, 1e-9));
      expect(scale.source, ColumnScaleSource.reading);
    });

    test('value equality and labels', () {
      const a = ColumnScale(0.98, ColumnScaleSource.reading);
      expect(a, const ColumnScale(0.98, ColumnScaleSource.reading));
      expect(
        a.hashCode,
        const ColumnScale(0.98, ColumnScaleSource.reading).hashCode,
      );
      expect(a, isNot(const ColumnScale(0.98, ColumnScaleSource.badge)));
      expect(a, isNot(const ColumnScale(0.99, ColumnScaleSource.reading)));
      expect(a.toString(), contains('reading'));
      for (final s in ColumnScaleSource.values) {
        expect(
          ColumnScale(1.0, s).isDefault,
          s == ColumnScaleSource.tooFewRows ||
              s == ColumnScaleSource.outOfRange,
          reason: s.name,
        );
      }
    });
  });

  group('the draft keeps the page scale', () {
    final pipeline = standardPipeline();

    // Values measured before the source was recorded: recording it must not
    // move them (the parser's scores depend on them).
    for (final (set, page, value) in [
      (synthetic, 's010', 1.0134782608695652),
      (synthetic, 's011', 0.9810869565217392),
      (synthetic, 's140', 0.9836065573770492),
      (synthetic, 's147', 0.994535519125683),
      (syntheticMlKit, 'm011', 0.9819565217391306),
      (syntheticMlKit, 'm140', 0.9836065573770492),
    ]) {
      test('$page is measured, not the default', () async {
        final draft = await pipeline.fromScan(await set.loadScan(page));
        final scale = draft.columnScale;
        expect(scale, isNotNull);
        expect(scale!.isDefault, isFalse);
        expect(scale.value, closeTo(value, 1e-12));
      });
    }

    // Numbers, headwords and meanings, but no reading cell and no POS badge.
    final bare = OcrScan(
      japanese: OcrPage(
        lines: [
          ..._numbers(3),
          for (final (i, h) in ['雨', '川', '山'].indexed)
            _line(h, 0.16, 0.2 + 0.05 * i),
        ],
      ),
      korean: OcrPage(
        lines: [
          for (final (i, m) in ['비', '강', '산'].indexed)
            _line(m, 0.55, 0.2 + 0.05 * i),
        ],
      ),
    );

    for (final template in ['vocab.list', 'vocab.entry']) {
      test('a page without reading or badge columns records the default '
          '($template)', () async {
        final draft = await pipeline.fromScan(bare, templateId: template);
        expect(draft.columnScale, isNotNull);
        expect(draft.columnScale!.isDefault, isTrue);
        expect(draft.columnScale!.source, ColumnScaleSource.tooFewRows);
        expect(draft.columnScale!.value, 1.0);
      });
    }

    test('copyWith and replaceEntry keep the scale; it takes part in ==', () {
      const scale = ColumnScale(1.0, ColumnScaleSource.outOfRange);
      const entry = CapturedEntry(
        no: '0001',
        headword: '雨',
        readings: ['あめ'],
        pos: PartOfSpeech.noun,
        meaning: '비',
        important: false,
      );
      const draft = CaptureDraft(
        templateId: 'vocab.list',
        meta: PageMeta(day: 1),
        entries: [entry],
        columnScale: scale,
      );
      expect(draft.copyWith(meta: const PageMeta(day: 2)).columnScale, scale);
      expect(
        draft.replaceEntry(0, entry.copyWith(included: false)).columnScale,
        scale,
      );
      expect(draft.copyWith(), draft);
      expect(draft.copyWith().hashCode, draft.hashCode);
      const unmeasured = CaptureDraft(
        templateId: 'vocab.list',
        meta: PageMeta(day: 1),
        entries: [entry],
      );
      expect(unmeasured.columnScale, isNull);
      expect(draft, isNot(unmeasured));
    });
  });
}
