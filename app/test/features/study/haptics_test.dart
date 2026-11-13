// N5: light taps, one per act — an answer (selection), a right pick (light),
// a wrong pick (medium), the session's end (success) — and none for the
// rest; none at all with 햅틱 off.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori/features/reminders/review_notifications.dart';
import 'package:shiori/features/study/haptics.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import '../../support/harness.dart';
import '../../support/study_modes.dart';

const _selection = 'HapticFeedbackType.selectionClick';
const _light = 'HapticFeedbackType.lightImpact';
const _medium = 'HapticFeedbackType.mediumImpact';
const _success = 'HapticFeedbackType.successNotification';

void main() {
  late List<String> taps;

  setUp(() => taps = []);

  void listen(WidgetTester tester) {
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
  }

  List<Override> extra({bool haptics = true, int goal = 3}) => [
    nudgeStoreProvider.overrideWithValue(
      InMemoryNudgeStore(
        NudgeSettings(offered: true, haptics: haptics, swipeHinted: true),
      ),
    ),
    reviewNotificationsProvider.overrideWithValue(
      InMemoryReviewNotifications(state: NotificationPermission.denied),
    ),
    studySettingsProvider.overrideWithValue(StudySettings(dailyGoal: goal)),
    speechProvider.overrideWithValue(RecordingSpeech()),
    accentTableProvider.overrideWith((ref) async => AccentTable.empty),
  ];

  Future<(TestBlocks, List<Word>)> open(
    WidgetTester tester,
    StudyMode mode, {
    bool haptics = true,
    int goal = 3,
  }) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final words = await seedModeWords(blocks);
    await blocks.preferences.save(StudyPreferences(mode: mode));
    await tester.pumpWidget(
      app(
        blocks,
        extra: extra(haptics: haptics, goal: goal),
      ),
    );
    await tester.pumpAndSettle();
    listen(tester);
    await tester.tap(find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    expect(taps, isEmpty, reason: 'opening a session is quiet');
    return (blocks, words);
  }

  testWidgets('알고있음 and 다시 학습: one selection tap each', (tester) async {
    await open(tester, StudyMode.meaning);
    await tester.tap(find.text('다시 학습'));
    await tester.pumpAndSettle();
    expect(taps, [_selection]);
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(taps, [_selection, _selection]);
  });

  testWidgets('뜻 보기, 이미 알아요 and 되돌리기 are quiet', (tester) async {
    await open(tester, StudyMode.meaning);
    await tester.tap(find.text('뜻 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이미 알아요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(taps, isEmpty);
  });

  testWidgets('the session end: one success tap after the last answer', (
    tester,
  ) async {
    await open(tester, StudyMode.meaning, goal: 2);
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    expect(taps, [_selection, _selection, _success]);
  });

  testWidgets('the session end with reduced motion taps too', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester, StudyMode.meaning, goal: 1);
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    expect(taps, [_selection, _success]);
  });

  testWidgets('객관식: right is light, wrong is medium, 다음 is quiet', (
    tester,
  ) async {
    final (_, words) = await open(tester, StudyMode.choice);
    await tester.tap(find.byKey(ValueKey('option-${words[0].id}')));
    await tester.pumpAndSettle();
    expect(taps, [_light]);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(taps, [_light]);

    final wrong = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('option-') &&
          (w.key! as ValueKey<String>).value != 'option-${words[1].id}',
    );
    await tester.tap(wrong.first);
    await tester.pumpAndSettle();
    expect(taps, [_light, _medium]);
  });

  testWidgets('듣고 맞히기 taps the same way', (tester) async {
    final (_, words) = await open(tester, StudyMode.listening);
    await tester.tap(find.byKey(ValueKey('option-${words[0].id}')));
    await tester.pumpAndSettle();
    expect(taps, [_light]);
  });

  testWidgets('햅틱 off: no tap at all', (tester) async {
    await open(tester, StudyMode.meaning, haptics: false, goal: 1);
    await tester.tap(find.text('알고있음'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    expect(taps, isEmpty);
  });

  test('the block calls one kind each, nothing when off', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.arguments as String);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    const on = Haptics(enabled: true);
    await on.answer();
    await on.right();
    await on.wrong();
    await on.sessionEnd();
    expect(calls, [_selection, _light, _medium, _success]);
    const off = Haptics(enabled: false);
    await off.answer();
    await off.right();
    await off.wrong();
    await off.sessionEnd();
    expect(calls, hasLength(4));
  });
}
