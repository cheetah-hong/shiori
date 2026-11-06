// Q5: an engine that boxes each word gives one Korean line as several
// boxes (`9,` · `별`). Boxes of one line that touch (a gap of at most 0.8
// of the line's height) are one line again, joined with a space. Kept
// apart: a wide gap, another row, another height, a box that is only a
// badge or only a number, a box after which a badge starts a new cell, text
// set sideways, Japanese. With nothing to join, the same list comes back.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/fragment_collector.dart';
import 'package:shiori_core/src/extract/touching_boxes.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

const double _h = 0.014;

OcrLine _box(
  String t,
  double x,
  double w, {
  double y = 0.39,
  double h = _h,
  double c = 0.7,
}) => OcrLine(text: t, x: x, y: y, width: w, height: h, confidence: c);

List<String> _texts(List<OcrLine> lines) => [for (final l in lines) l.text];

void main() {
  group('Q5 touching Korean boxes', () {
    test('two boxes of one line: one line, joined with a space', () {
      final out = joinTouchingKorean([
        _box('9,', 0.600, 0.013, c: 0.7),
        _box('별', 0.620, 0.011, c: 0.5),
      ]);
      expect(_texts(out), ['9, 별']);
      final l = out.single;
      expect(l.x, closeTo(0.600, 1e-9));
      expect(l.x + l.width, closeTo(0.631, 1e-9));
      expect(l.confidence, 0.5);
    });

    test('three boxes in a row, in any order: one line', () {
      final out = joinTouchingKorean([
        _box('편', 0.660, 0.026),
        _box('오른쪽,', 0.600, 0.040),
        _box('바른', 0.645, 0.012),
      ]);
      expect(_texts(out), ['오른쪽, 바른 편']);
    });

    test('a narrow box of one letter still joins', () {
      expect(
        _texts(
          joinTouchingKorean([
            _box('20,', 0.659, 0.026, h: 0.016),
            _box('꽃', 0.694, 0.007, h: 0.015),
          ]),
        ),
        ['20, 꽃'],
      );
    });

    test('a gap wider than 0.8 of the height: apart', () {
      final out = joinTouchingKorean([
        _box('사과', 0.600, 0.028),
        _box('배', 0.600 + 0.028 + _h * 1.0, 0.014),
      ]);
      expect(_texts(out), ['사과', '배']);
    });

    test('another row: apart', () {
      final out = joinTouchingKorean([
        _box('사과', 0.600, 0.028),
        _box('배', 0.632, 0.014, y: 0.39 + _h * 1.2),
      ]);
      expect(_texts(out), ['사과', '배']);
    });

    test('another height: apart', () {
      final out = joinTouchingKorean([
        _box('사과', 0.600, 0.028),
        _box('배', 0.632, 0.028, y: 0.39 - _h / 2, h: _h * 2),
      ]);
      expect(out, hasLength(2));
    });

    test('a box that is only a badge or only a number: apart', () {
      expect(
        _texts(
          joinTouchingKorean([
            _box('명', 0.600, 0.014),
            _box('사과', 0.620, 0.028),
          ]),
        ),
        ['명', '사과'],
      );
      expect(
        _texts(
          joinTouchingKorean([
            _box('8', 0.600, 0.008),
            _box('고르다', 0.612, 0.042),
          ]),
        ),
        ['8', '고르다'],
      );
    });

    test('a badge starts the next box: a new cell, apart', () {
      final out = joinTouchingKorean([
        _box('꽃, 화', 0.600, 0.034),
        _box('명 나무', 0.640, 0.050),
      ]);
      expect(out, hasLength(2));
    });

    test('text set sideways (boxes taller than their text is wide): '
        'apart', () {
      final out = joinTouchingKorean([
        _box('새벽 녘', 0.461, 0.013, y: 0.309, h: 0.050),
        _box('아침때', 0.480, 0.012, y: 0.325, h: 0.035),
      ]);
      expect(out, hasLength(2));
    });

    test('Japanese in a box: apart', () {
      final out = joinTouchingKorean([
        _box('사과', 0.600, 0.028),
        _box('りんご', 0.632, 0.040),
      ]);
      expect(out, hasLength(2));
    });

    test('nothing to join: the same list', () {
      final lines = [
        _box('사과, 능금', 0.600, 0.070),
        _box('배', 0.600, 0.014, y: 0.45),
      ];
      expect(identical(joinTouchingKorean(lines), lines), isTrue);
    });

    test('the word extractor reads the joined line as one meaning', () {
      final fragments = collectFragments(
        scan(ko: [_box('9,', 0.600, 0.013), _box('별', 0.620, 0.011)]),
      );
      final korean = [
        for (final f in fragments)
          if (f.pass == OcrPass.korean && f.kind != FragmentKind.noise) f.text,
      ];
      expect(korean, ['9, 별']);
    });
  });
}
