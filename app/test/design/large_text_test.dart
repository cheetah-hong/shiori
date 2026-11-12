// U1: the main screens at the default text size, twice it and about the
// largest accessibility size, light and dark, lay out without an overflow
// or any other error (a layout error fails the test). Made-up words only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/study/study_mode_labels.dart';

import '../support/design.dart';
import '../support/harness.dart';

/// Opens the hidden side of each study card, or answers it.
Future<void> _turn(WidgetTester tester, String screen) async {
  switch (screen) {
    case 'study meaning':
      await tapDesignText(tester, '뜻 보기');
      await tapDesignText(tester, '읽기 보기');
    case 'study recall':
      await tapDesignText(tester, '일본어 보기');
    case 'study listening' || 'study choice':
      await tapDesignText(tester, '말 둘');
      expect(find.text(StudyModeLabels.next), findsOneWidget);
  }
}

void _useScale(WidgetTester tester, double scale, Brightness brightness) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

void main() {
  for (final screen in designScreens) {
    for (final scale in designTextScales) {
      testWidgets('$screen at ×$scale', (tester) async {
        _useScale(tester, scale, Brightness.light);
        await openDesignScreen(tester, screen);
        await _turn(tester, screen.name);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('$screen dark', (tester) async {
      _useScale(tester, 1, Brightness.dark);
      await openDesignScreen(tester, screen);
      await _turn(tester, screen.name);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in designTextScales) {
    testWidgets('오늘 학습 끝 at ×$scale', (tester) async {
      _useScale(tester, scale, Brightness.light);
      await openDesignScreen(
        tester,
        designScreens.firstWhere((s) => s.name == 'study meaning'),
      );
      for (var i = 0; i < 5; i++) {
        await tapDesignText(tester, '알고있음');
      }
      expect(find.text('오늘 학습 끝'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home header with today\'s count at ×2.0 and ×3.1', (
    tester,
  ) async {
    for (final scale in [2.0, 3.1]) {
      _useScale(tester, scale, Brightness.light);
      await openDesignScreen(
        tester,
        designScreens.firstWhere((s) => s.name == 'study meaning'),
      );
      await tapDesignText(tester, '알고있음');
      await tester.tap(find.byTooltip('학습 그만하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('외움'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
