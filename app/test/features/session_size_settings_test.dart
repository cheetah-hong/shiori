// 설정 › 학습 세션: the daily goal (10 · 20 · 30 · 50 · 전부) and the card
// order switch, stored as soon as they are picked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/settings/settings_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

final class _FailingPreferences implements StudyPreferencesRepository {
  @override
  Future<StudyPreferences> load() async => const StudyPreferences();

  @override
  Future<void> save(StudyPreferences preferences) async =>
      throw const _SaveFailure();
}

final class _SaveFailure implements Exception {
  const _SaveFailure();
}

void main() {
  Set<DailyGoal> selectedGoal(WidgetTester tester) => tester
      .widget<SegmentedButton<DailyGoal>>(
        find.byType(SegmentedButton<DailyGoal>),
      )
      .selected;

  bool shuffleOn(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '카드 순서 섞기'))
      .value;

  testWidgets('nothing stored: 10 cards a day, cards shuffled', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('학습 세션'), findsOneWidget);
    expect(find.text('하루 목표'), findsOneWidget);
    for (final label in ['10', '20', '30', '50', '전부']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(selectedGoal(tester), {DailyGoal.ten});
    expect(shuffleOn(tester), isTrue);
  });

  testWidgets('picking a goal stores it at once', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    expect((await blocks.preferences.load()).dailyGoal, DailyGoal.twenty);
    expect(selectedGoal(tester), {DailyGoal.twenty});

    await tester.tap(find.text('전부'));
    await tester.pumpAndSettle();
    final stored = await blocks.preferences.load();
    expect(stored.dailyGoal, DailyGoal.all);
    expect(stored.shuffle, isTrue, reason: 'the other option stays');
    expect(selectedGoal(tester), {DailyGoal.all});
  });

  testWidgets('the switch turns the card order shuffle off and on', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.preferences.save(
      const StudyPreferences(dailyGoal: DailyGoal.thirty),
    );
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('카드 순서 섞기'));
    await tester.pumpAndSettle();
    var stored = await blocks.preferences.load();
    expect(stored.shuffle, isFalse);
    expect(stored.dailyGoal, DailyGoal.thirty);
    expect(shuffleOn(tester), isFalse);

    await tester.tap(find.text('카드 순서 섞기'));
    await tester.pumpAndSettle();
    stored = await blocks.preferences.load();
    expect(stored.shuffle, isTrue);
  });

  testWidgets('the other options stay when the goal changes', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await blocks.preferences.save(
      const StudyPreferences(mode: StudyMode.recall, shuffle: false),
    );
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50'));
    await tester.pumpAndSettle();
    expect(
      await blocks.preferences.load(),
      const StudyPreferences(
        mode: StudyMode.recall,
        shuffle: false,
        dailyGoal: DailyGoal.fifty,
      ),
    );
  });

  testWidgets('a failed save says so', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks(preferences: _FailingPreferences());
    await tester.pumpWidget(screen(blocks, const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했어요. 다시 시도해 주세요'), findsOneWidget);
  });
}
