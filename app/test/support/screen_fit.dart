import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/study/study_mode_labels.dart';
import 'package:shiori_core/shiori_core.dart';

import 'design.dart';
import 'harness.dart';
import 'study_modes.dart';

/// iPhone screens the app supports, in logical points: SE (3rd gen),
/// 13 mini, 17, 17 Pro Max.
const fitSizes = {
  'SE': Size(375, 667),
  'mini': Size(375, 812),
  '17': Size(402, 874),
  'Pro Max': Size(440, 956),
};

/// Text sizes checked: the default, twice, and about the largest
/// accessibility size iOS offers.
const fitScales = [1.0, 2.0, 3.1];

/// Sets the screen to [size] (at 3 pixels a point) and the text size.
void useFit(
  WidgetTester tester,
  Size size,
  double scale, {
  Brightness brightness = Brightness.light,
}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Starts the app on [screen]'s data at the size [useFit] set (unlike
/// [openDesignScreen], which uses one phone size) and opens it.
Future<TestBlocks> openFitScreen(
  WidgetTester tester,
  DesignScreen screen,
) async {
  final blocks = TestBlocks();
  if (screen.words) {
    await seedModeWords(blocks);
    await blocks.preferences.save(
      StudyPreferences(mode: screen.mode ?? StudyMode.meaning),
    );
  }
  await tester.pumpWidget(app(blocks, extra: designBlocks()));
  await tester.pumpAndSettle();
  await screen.open?.call(tester);
  return blocks;
}

/// Opens the hidden side of a study card, or answers it.
Future<void> turnStudyCard(WidgetTester tester, StudyMode mode) async {
  switch (mode) {
    case StudyMode.meaning:
      await tapDesignText(tester, '뜻 보기');
      await tapDesignText(tester, '읽기 보기');
    case StudyMode.recall:
      await tapDesignText(tester, '일본어 보기');
    case StudyMode.listening || StudyMode.choice:
      await tapDesignText(tester, '말 둘');
      expect(find.text(StudyModeLabels.next), findsOneWidget);
  }
}

DesignScreen designScreen(String name) =>
    designScreens.firstWhere((s) => s.name == name);

/// Whether two rectangles share any area (touching edges do not count).
bool overlaps(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 0.5 && i.height > 0.5;
}

/// Every button on screen (filled, outlined, text and icon buttons).
Finder get anyButton =>
    find.byWidgetPredicate((w) => w is ButtonStyleButton || w is IconButton);
