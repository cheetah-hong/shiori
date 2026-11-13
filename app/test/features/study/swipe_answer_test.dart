// N6: a self-graded card can be swiped — right 알고있음, left 다시 학습 —
// past 30% of its width or flung; short of it the card comes back and
// nothing is stored. Not in the multiple-choice ways, not from the screen's
// left edge (the back gesture), not moving with reduced motion, and as
// actions for VoiceOver. The buttons stay.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori/features/study/swipe_answer.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import '../../support/harness.dart';
import '../../support/study_modes.dart';

void main() {
  late TestBlocks blocks;
  late List<Word> words;
  late InMemoryNudgeStore store;

  List<Override> extra(int goal) => [
    nudgeStoreProvider.overrideWithValue(store),
    reviewNotificationsProvider.overrideWithValue(
      InMemoryReviewNotifications(state: NotificationPermission.denied),
    ),
    studySettingsProvider.overrideWithValue(StudySettings(dailyGoal: goal)),
    speechProvider.overrideWithValue(RecordingSpeech()),
    accentTableProvider.overrideWith((ref) async => AccentTable.empty),
  ];

  Future<void> open(
    WidgetTester tester, {
    StudyMode mode = StudyMode.meaning,
    int goal = 3,
    bool hinted = true,
  }) async {
    usePhoneSize(tester);
    blocks = TestBlocks();
    words = await seedModeWords(blocks);
    store = InMemoryNudgeStore(
      NudgeSettings(offered: true, swipeHinted: hinted),
    );
    await blocks.preferences.save(StudyPreferences(mode: mode));
    await tester.pumpWidget(app(blocks, extra: extra(goal)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
  }

  Finder card() => find.byType(SwipeToAnswer);

  Future<ReviewCard?> stored(String id, [StudyMode mode = StudyMode.meaning]) =>
      blocks.reviews.card(id, mode: mode);

  /// A slow drag (no fling) of [dx] from the card's centre.
  Future<void> slowDrag(WidgetTester tester, double dx) async {
    await tester.timedDrag(
      card(),
      Offset(dx, 0),
      const Duration(milliseconds: 1500),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('past the threshold right: 알고있음', (tester) async {
    await open(tester);
    expect(find.text('語一'), findsOneWidget);
    await slowDrag(tester, 160);
    expect((await stored(words[0].id))?.level, 4);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('語二'), findsOneWidget);
  });

  testWidgets('past the threshold left: 다시 학습', (tester) async {
    await open(tester);
    await slowDrag(tester, -160);
    final card0 = await stored(words[0].id);
    expect((card0?.level, card0?.dueAt), (1, testNow));
    final logs = await blocks.reviews.logs();
    expect(logs.single.answer, Answer.retry);
    expect(find.text('0 / 3'), findsOneWidget);
  });

  testWidgets('short of it: back in place, nothing stored', (tester) async {
    await open(tester);
    final before = tester.getTopLeft(find.text('語一'));
    await slowDrag(tester, 70);
    expect(await blocks.reviews.logs(), isEmpty);
    expect(tester.getTopLeft(find.text('語一')), before);
    await slowDrag(tester, -70);
    expect(await blocks.reviews.logs(), isEmpty);
  });

  testWidgets('a fling answers; a tiny fast flick does not', (tester) async {
    await open(tester);
    await tester.fling(card(), const Offset(30, 0), 2000);
    await tester.pumpAndSettle();
    expect(await blocks.reviews.logs(), isEmpty);
    await tester.fling(card(), const Offset(60, 0), 1500);
    await tester.pumpAndSettle();
    expect((await stored(words[0].id))?.level, 4);
  });

  testWidgets('the card follows the finger and tilts, then comes back', (
    tester,
  ) async {
    await open(tester);
    final before = tester.getCenter(find.text('語一'));
    final gesture = await tester.startGesture(tester.getCenter(card()));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(tester.getCenter(find.text('語一')).dx, greaterThan(before.dx + 40));
    expect(find.text('알고있음'), findsWidgets, reason: 'its label shows');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('語一')), before);
  });

  testWidgets('one selection tap when the threshold is crossed', (
    tester,
  ) async {
    await open(tester);
    final taps = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          taps.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await slowDrag(tester, 160);
    expect(taps, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('a drag from the screen\'s left edge is left alone', (
    tester,
  ) async {
    await open(tester);
    final y = tester.getCenter(card()).dy;
    expect(tester.getTopLeft(card()).dx, lessThan(SwipeToAnswer.edge));
    await tester.timedDragFrom(
      Offset(SwipeToAnswer.edge - 4, y),
      const Offset(220, 0),
      const Duration(milliseconds: 1500),
    );
    await tester.pumpAndSettle();
    expect(await blocks.reviews.logs(), isEmpty);
  });

  testWidgets('일본어 떠올리기 swipes too', (tester) async {
    await open(tester, mode: StudyMode.recall);
    await slowDrag(tester, 160);
    expect((await stored(words[0].id, StudyMode.recall))?.level, 4);
  });

  testWidgets('객관식 and 듣고 맞히기 have no swipe', (tester) async {
    await open(tester, mode: StudyMode.choice);
    expect(card(), findsNothing);
    await tester.timedDrag(
      find.text('語一'),
      const Offset(200, 0),
      const Duration(milliseconds: 1500),
    );
    await tester.pumpAndSettle();
    expect(await blocks.reviews.logs(mode: StudyMode.choice), isEmpty);
  });

  testWidgets('the last card swiped ends the session', (tester) async {
    await open(tester, goal: 1);
    await slowDrag(tester, 160);
    expect(find.text('오늘 학습 끝'), findsOneWidget);
  });

  testWidgets('reduced motion: the card stays still, the answer is the same', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester);
    final before = tester.getTopLeft(find.text('語一'));
    final gesture = await tester.startGesture(tester.getCenter(card()));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(140, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.text('語一')), before, reason: 'no move');
    await gesture.up();
    await tester.pumpAndSettle();
    expect((await stored(words[0].id))?.level, 4);
  });

  testWidgets('VoiceOver: 알고있음 and 다시 학습 as actions on the card', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    SemanticsNode node() => tester.getSemantics(card());
    Map<String, int> actions() => {
      for (final id
          in node().getSemanticsData().customSemanticsActionIds ??
              const <int>[])
        CustomSemanticsAction.getAction(id)!.label!: id,
    };
    expect(actions().keys, containsAll(['알고있음', '다시 학습']));

    node().owner!.performAction(
      node().id,
      SemanticsAction.customAction,
      actions()['다시 학습'],
    );
    await tester.pumpAndSettle();
    expect((await blocks.reviews.logs()).single.answer, Answer.retry);

    node().owner!.performAction(
      node().id,
      SemanticsAction.customAction,
      actions()['알고있음'],
    );
    await tester.pumpAndSettle();
    expect((await blocks.reviews.logs()).last.answer, Answer.known);
    semantics.dispose();
  });

  testWidgets('large text: an up-and-down drag scrolls, answers nothing', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    final scrollable = find.byType(Scrollable).first;
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.timedDrag(
      card(),
      const Offset(0, -200),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(before),
    );
    expect(await blocks.reviews.logs(), isEmpty);
    // A sideways drag still answers.
    await slowDrag(tester, 180);
    expect((await stored(words[0].id))?.level, 4);
  });

  group('the hint line', () {
    testWidgets('shown until the first swipe, then never', (tester) async {
      await open(tester, hinted: false);
      expect(find.text('카드를 밀어서도 답할 수 있어요'), findsOneWidget);
      await slowDrag(tester, 160);
      expect(find.text('카드를 밀어서도 답할 수 있어요'), findsNothing);
      expect(store.settings.swipeHinted, isTrue);
    });

    testWidgets('a session ended with buttons also counts', (tester) async {
      await open(tester, hinted: false, goal: 1);
      await tester.tap(find.text('알고있음'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습 끝'), findsOneWidget);
      expect(store.settings.swipeHinted, isTrue);
    });

    testWidgets('not in 객관식', (tester) async {
      await open(tester, mode: StudyMode.choice, hinted: false);
      expect(find.text('카드를 밀어서도 답할 수 있어요'), findsNothing);
    });

    testWidgets('not once seen', (tester) async {
      await open(tester);
      expect(find.text('카드를 밀어서도 답할 수 있어요'), findsNothing);
    });
  });
}
