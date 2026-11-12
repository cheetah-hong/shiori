// How many cards a session holds: 홈 follows the daily goal, a playlist
// studies every card it can. The buttons say how many. Made-up words only.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';
import '../support/session_words.dart';

void main() {
  /// A: w0, w1 due + w2..w31 new (32 to study); B: w40..w47 new.
  /// 전체: 2 due + 38 new = 40.
  Future<TestBlocks> seeded({
    StudyPreferences preferences = const StudyPreferences(shuffle: false),
  }) async {
    final blocks = TestBlocks();
    await blocks.preferences.save(preferences);
    await seedMadeUpPlaylist(blocks.library, 'a', '목록 A', [
      for (var n = 0; n < 32; n++) n,
    ]);
    await seedMadeUpPlaylist(blocks.library, 'b', '목록 B', [
      for (var n = 40; n < 48; n++) n,
    ]);
    await blocks.reviews.saveCard(dueCardOf(0, hours: 2));
    await blocks.reviews.saveCard(dueCardOf(1));
    return blocks;
  }

  group('홈 follows the daily goal', () {
    for (final (goal, cards) in [
      (DailyGoal.ten, 10),
      (DailyGoal.twenty, 20),
      (DailyGoal.thirty, 30),
      (DailyGoal.fifty, 40),
      (DailyGoal.all, 40),
    ]) {
      testWidgets('$goal: 오늘 학습 시작 · $cards장, a session of $cards', (
        tester,
      ) async {
        usePhoneSize(tester);
        final blocks = await seeded(
          preferences: StudyPreferences(dailyGoal: goal, shuffle: false),
        );
        await tester.pumpWidget(app(blocks));
        await tester.pumpAndSettle();
        await tester.tap(find.text('오늘 학습 시작 · $cards장'));
        await tester.pumpAndSettle();
        expect(find.text('0 / $cards'), findsOneWidget);
      });
    }

    testWidgets('전부 says every card is studied', (tester) async {
      usePhoneSize(tester);
      final blocks = await seeded(
        preferences: const StudyPreferences(
          dailyGoal: DailyGoal.all,
          shuffle: false,
        ),
      );
      await tester.pumpWidget(app(blocks));
      await tester.pumpAndSettle();
      // Every new word goes in: no 「· n개 중」, and the memo adds up to all.
      expect(find.text('38개'), findsOneWidget);
      expect(find.textContaining('개 중'), findsNothing);
      expect(
        find.textContaining('복습 2장을 먼저, 남은 38장은 새 단어로 — 오늘 40장.'),
        findsOneWidget,
      );
    });

    testWidgets('the count follows a goal picked meanwhile', (tester) async {
      usePhoneSize(tester);
      final blocks = await seeded();
      await tester.pumpWidget(app(blocks));
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습 시작 · 10장'), findsOneWidget);

      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습 시작 · 20장'), findsOneWidget);
    });

    for (final (row, cards) in [('scope-a', 32), ('scope-all', 10)]) {
      testWidgets('재생목록 골라 학습 › $row: a session of $cards', (tester) async {
        usePhoneSize(tester);
        final blocks = await seeded();
        await tester.pumpWidget(app(blocks));
        await tester.pumpAndSettle();

        await tester.tap(find.text('재생목록 골라 학습'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(row)));
        await tester.pumpAndSettle();
        expect(find.text('0 / $cards'), findsOneWidget);
      });
    }
  });

  testWidgets('a playlist studies every card: 이 목록 학습 · 32장', (tester) async {
    usePhoneSize(tester);
    final blocks = await seeded();
    await tester.pumpWidget(
      screen(blocks, const PlaylistScreen(playlistId: 'a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 목록 학습 · 32장'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 32'), findsOneWidget);
  });

  group('더 학습하기 says how many cards it brings forward', () {
    /// A: w0..w24 waiting; nothing due, no new word.
    Future<TestBlocks> waiting(DailyGoal goal) async {
      final blocks = TestBlocks();
      await blocks.preferences.save(
        StudyPreferences(dailyGoal: goal, shuffle: false),
      );
      await seedMadeUpPlaylist(blocks.library, 'a', '목록 A', [
        for (var n = 0; n < 25; n++) n,
      ]);
      for (var n = 0; n < 25; n++) {
        await blocks.reviews.saveCard(waitingCardOf(n, days: 1 + n));
      }
      return blocks;
    }

    testWidgets('홈: as many as the daily goal', (tester) async {
      usePhoneSize(tester);
      final blocks = await waiting(DailyGoal.twenty);
      await tester.pumpWidget(app(blocks));
      await tester.pumpAndSettle();
      expect(find.textContaining('20장 미리 학습해요'), findsOneWidget);
      await tester.tap(find.text('더 학습하기'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 20'), findsOneWidget);
    });

    testWidgets('a playlist: every waiting card', (tester) async {
      usePhoneSize(tester);
      final blocks = await waiting(DailyGoal.twenty);
      await tester.pumpWidget(
        screen(blocks, const PlaylistScreen(playlistId: 'a')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('25장 미리 학습해요'), findsOneWidget);
      await tester.tap(find.text('더 학습하기'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 25'), findsOneWidget);
    });
  });

  group('card order', () {
    Future<String> firstHeadword(
      WidgetTester tester, {
      required bool shuffle,
    }) async {
      final blocks =
          await seeded(preferences: StudyPreferences(shuffle: shuffle))
            ..sessionRandom = () => Random(7);
      await tester.pumpWidget(
        screen(blocks, const PlaylistScreen(playlistId: 'a')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 목록 학습 · 32장'));
      await tester.pumpAndSettle();
      return [
        for (var n = 0; n < 32; n++)
          if (find.text('語$n').evaluate().isNotEmpty) '語$n',
      ].single;
    }

    testWidgets('off: the oldest due review first', (tester) async {
      usePhoneSize(tester);
      expect(await firstHeadword(tester, shuffle: false), '語0');
    });

    testWidgets('on: the seed decides, not the order of the list', (
      tester,
    ) async {
      usePhoneSize(tester);
      expect(await firstHeadword(tester, shuffle: true), isNot('語0'));
    });
  });
}
