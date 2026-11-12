// How many cards a session takes on a simulator: 설정 › 학습 세션, 홈 with a
// daily goal of 20 and of 전부, and a playlist that studies every card,
// shuffled.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/session_size_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. In-memory database, made-up word
// lists only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// Everyday words (headword, reading, meaning): 32 in 자연과 생활, 8 in 물건.
const _words = [
  ('水', 'みず', '물'),
  ('火', 'ひ', '불'),
  ('山', 'やま', '산'),
  ('川', 'かわ', '강'),
  ('空', 'そら', '하늘'),
  ('海', 'うみ', '바다'),
  ('雨', 'あめ', '비'),
  ('雪', 'ゆき', '눈'),
  ('花', 'はな', '꽃'),
  ('木', 'き', '나무'),
  ('鳥', 'とり', '새'),
  ('魚', 'さかな', '물고기'),
  ('犬', 'いぬ', '개'),
  ('猫', 'ねこ', '고양이'),
  ('本', 'ほん', '책'),
  ('車', 'くるま', '자동차'),
  ('町', 'まち', '마을'),
  ('駅', 'えき', '역'),
  ('学校', 'がっこう', '학교'),
  ('友達', 'ともだち', '친구'),
  ('朝', 'あさ', '아침'),
  ('夜', 'よる', '밤'),
  ('月', 'つき', '달'),
  ('星', 'ほし', '별'),
  ('風', 'かぜ', '바람'),
  ('石', 'いし', '돌'),
  ('島', 'しま', '섬'),
  ('森', 'もり', '숲'),
  ('歌', 'うた', '노래'),
  ('絵', 'え', '그림'),
  ('手紙', 'てがみ', '편지'),
  ('窓', 'まど', '창문'),
  ('椅子', 'いす', '의자'),
  ('机', 'つくえ', '책상'),
  ('鞄', 'かばん', '가방'),
  ('靴', 'くつ', '신발'),
  ('帽子', 'ぼうし', '모자'),
  ('傘', 'かさ', '우산'),
  ('時計', 'とけい', '시계'),
  ('鍵', 'かぎ', '열쇠'),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (providers load asynchronously on device).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> seed(ShioriDatabase database, DateTime now) async {
    final library = DriftLibraryRepository(database);
    final words = [
      for (final (i, (headword, reading, meaning)) in _words.indexed)
        Word(
          id: 'w$i',
          headword: headword,
          readings: [reading],
          meaning: meaning,
          createdAt: now.add(Duration(seconds: i)),
        ),
    ];
    await library.insertWords(words);
    for (final (id, name, from, to) in [
      ('nature', '자연과 생활', 0, 32),
      ('things', '물건', 32, 40),
    ]) {
      await library.savePlaylist(
        Playlist(
          id: id,
          name: name,
          createdAt: now,
          position: (await library.playlists()).length,
        ),
      );
      await library.addToPlaylist(id, [
        for (final w in words.sublist(from, to)) w.id,
      ], at: now);
    }
    final reviews = DriftReviewRepository(database);
    for (final id in ['w0', 'w1']) {
      await reviews.saveCard(
        ReviewCard(
          wordId: id,
          level: 2,
          dueAt: now.subtract(const Duration(hours: 1)),
          lastReviewedAt: now.subtract(const Duration(days: 3)),
        ),
      );
    }
    await DriftStudyPreferencesRepository(
      database,
    ).save(const StudyPreferences(dailyGoal: DailyGoal.twenty));
  }

  testWidgets('하루 목표, 이 목록 학습 · n장 and a shuffled session', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await seed(database, DateTime.now().subtract(const Duration(days: 1)));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );

    await waitFor(tester, find.text('오늘 학습 시작 · 20장'));
    await shot(tester, '116_home_daily_goal_20');

    await tap(tester, find.byTooltip('설정'));
    await waitFor(tester, find.text('카드 순서 섞기'));
    await shot(tester, '115_settings_study_session');

    await tap(tester, find.text('전부'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('오늘 학습 시작 · 40장'));
    await shot(tester, '117_home_daily_goal_all');

    await tap(tester, find.text('자연과 생활').first);
    await waitFor(tester, find.text('이 목록 학습 · 32장'));
    await shot(tester, '118_playlist_study_all');

    await tap(tester, find.text('이 목록 학습 · 32장'));
    await waitFor(tester, find.text('0 / 32'));
    await shot(tester, '119_playlist_session_shuffled');
  });
}
