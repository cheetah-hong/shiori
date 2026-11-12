import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import 'harness.dart';
import 'study_modes.dart';

/// Speech that is there (so 듣고 맞히기 can be picked) and an empty accent
/// table, as the study-mode tests use.
List<Override> designBlocks() => [
  speechProvider.overrideWithValue(RecordingSpeech()),
  accentTableProvider.overrideWith((ref) async => AccentTable.empty),
];

/// Text sizes checked: the default, twice, and about the largest
/// accessibility size iOS offers.
const designTextScales = [1.0, 2.0, 3.1];

/// Taps the first [text] (or text containing it), scrolling the page down
/// until it is built.
Future<void> tapDesignText(
  WidgetTester tester,
  String text, {
  bool contains = false,
}) async {
  final finder = contains ? find.textContaining(text) : find.text(text);
  // Scrolls down until it is built; the same text may be there twice (the
  // sample pages), so the first one is taken.
  final page = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.drag(page, const Offset(0, -200));
    await tester.pump();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// A main screen reached from 홈, with or without words in the library.
final class DesignScreen {
  const DesignScreen(this.name, {required this.words, this.open, this.mode});

  final String name;

  /// Five made-up words in playlist 「모음」 ([seedModeWords]).
  final bool words;

  /// Study mode saved before the app starts (학습 screens).
  final StudyMode? mode;

  /// How to get there from 홈; null stays on 홈.
  final Future<void> Function(WidgetTester tester)? open;

  @override
  String toString() => name;
}

Future<void> _study(WidgetTester tester) =>
    tapDesignText(tester, '오늘 학습 시작', contains: true);

/// 홈 (empty and with words), 찍기, 검토, the four study modes, a playlist,
/// 재생목록 편집, 설정 and 정보.
final designScreens = [
  const DesignScreen('home empty', words: false),
  const DesignScreen('home', words: true),
  DesignScreen(
    'capture',
    words: false,
    open: (t) => tapDesignText(t, '페이지 등록'),
  ),
  DesignScreen(
    'review',
    words: false,
    open: (t) async {
      await tapDesignText(t, '페이지 등록');
      await tapDesignText(t, 'DAY 01 자연, 몸');
    },
  ),
  const DesignScreen(
    'study meaning',
    words: true,
    mode: StudyMode.meaning,
    open: _study,
  ),
  const DesignScreen(
    'study recall',
    words: true,
    mode: StudyMode.recall,
    open: _study,
  ),
  const DesignScreen(
    'study listening',
    words: true,
    mode: StudyMode.listening,
    open: _study,
  ),
  const DesignScreen(
    'study choice',
    words: true,
    mode: StudyMode.choice,
    open: _study,
  ),
  DesignScreen('playlist', words: true, open: (t) => tapDesignText(t, '모음')),
  DesignScreen(
    'playlists edit',
    words: true,
    open: (t) => tapDesignText(t, '편집'),
  ),
  DesignScreen(
    'settings',
    words: true,
    open: (t) async {
      await t.tap(find.byTooltip('설정'));
      await t.pumpAndSettle();
    },
  ),
  DesignScreen(
    'about',
    words: true,
    open: (t) async {
      await t.tap(find.byTooltip('정보'));
      await t.pumpAndSettle();
    },
  ),
];

/// Starts the app on [screen]'s data and opens it.
Future<TestBlocks> openDesignScreen(
  WidgetTester tester,
  DesignScreen screen,
) async {
  usePhoneSize(tester);
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
