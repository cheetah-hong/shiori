// The redrawn screens on a simulator: 홈 as a day sheet (light, dark, empty,
// large text), the first-run guide, the opening, the study cards, capture,
// review, a playlist, settings and 정보.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/design_pass_screenshots_test.dart
//
// Screenshots land in docs/screenshots/ (130–149). In-memory database,
// everyday words only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

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
  ('本', 'ほん', '책'),
  ('駅', 'えき', '역'),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(
    WidgetTester tester,
    String name, {
    bool settle = true,
  }) async {
    if (settle) await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.textContaining(text);
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<ShioriDatabase> seeded({StudyMode mode = StudyMode.meaning}) async {
    final database = ShioriDatabase.memory();
    final now = DateTime.now();
    final library = DriftLibraryRepository(database);
    final words = [
      for (final (i, (h, r, m)) in _words.indexed)
        Word(
          id: 'w$i',
          headword: h,
          readings: [r],
          meaning: m,
          createdAt: now.subtract(Duration(days: 3, seconds: -i)),
          example: i == 0 ? const Example(ja: '水を飲む。', ko: '물을 마신다.') : null,
        ),
    ];
    await library.insertWords(words);
    for (final (id, name, from, to) in [
      ('nature', '자연', 0, 12),
      ('things', '물건과 장소', 12, 14),
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
          reviewCount: 2,
        ),
      );
    }
    for (final days in [1, 2]) {
      await reviews.addLog(
        ReviewLog(
          wordId: 'w2',
          answer: Answer.known,
          at: now.subtract(Duration(days: days)),
          levelBefore: 0,
          levelAfter: 1,
          retriesInSession: 0,
        ),
      );
    }
    await DriftStudyPreferencesRepository(
      database,
    ).save(StudyPreferences(mode: mode, dailyGoal: DailyGoal.ten));
    return database;
  }

  Future<ShioriDatabase> start(
    WidgetTester tester, {
    bool words = true,
    StudyMode mode = StudyMode.meaning,
    bool firstLaunch = false,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    final database = words ? await seeded(mode: mode) : ShioriDatabase.memory();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          onboardingStoreProvider.overrideWithValue(InMemoryOnboardingStore()),
        ],
        child: ShioriApp(firstLaunch: firstLaunch),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return database;
  }

  Future<void> reset(WidgetTester tester, ShioriDatabase database) async {
    await tester.pumpWidget(const SizedBox());
    await database.close();
    tester.platformDispatcher.clearAllTestValues();
  }

  testWidgets('홈 as a day sheet', (tester) async {
    var db = await start(tester);
    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    await shot(tester, '130_home_day_sheet');
    await tapText(tester, '뜻 맞히기');
    await shot(tester, '131_home_mode_menu');
    await reset(tester, db);

    db = await start(tester, brightness: Brightness.dark);
    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    await shot(tester, '132_home_dark');
    await reset(tester, db);

    db = await start(tester, words: false);
    await waitFor(tester, find.text('첫 페이지 등록하기'));
    await shot(tester, '133_home_empty');
    await reset(tester, db);

    db = await start(tester, textScale: 2);
    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    await shot(tester, '134_home_large_text');
    await reset(tester, db);
  });

  testWidgets('the opening and the first-run guide', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final db = ShioriDatabase.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          onboardingStoreProvider.overrideWithValue(InMemoryOnboardingStore()),
        ],
        child: const ShioriApp(firstLaunch: true),
      ),
    );
    await tester.pump();
    // Frames on a simulator run behind the clock; wait a little longer than
    // the timeline says for the flash and the stroke.
    await tester.pump(const Duration(milliseconds: 700));
    await shot(tester, '135_opening_flash', settle: false);
    await tester.pump(const Duration(milliseconds: 280));
    await shot(tester, '136_opening_shi', settle: false);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('건너뛰기'));
    await shot(tester, '137_onboarding_1');
    await tapText(tester, '다음');
    await tapText(tester, '다음');
    await shot(tester, '138_onboarding_3');
    await reset(tester, db);
  });

  testWidgets('the study cards', (tester) async {
    var db = await start(tester);
    await tapText(tester, '오늘 학습 시작');
    await shot(tester, '139_study_meaning');
    await tapText(tester, '뜻 보기');
    await shot(tester, '140_study_meaning_shown');
    await reset(tester, db);

    db = await start(tester, mode: StudyMode.recall);
    await tapText(tester, '오늘 학습 시작');
    await shot(tester, '141_study_recall');
    await reset(tester, db);

    db = await start(tester, mode: StudyMode.choice);
    await tapText(tester, '오늘 학습 시작');
    await shot(tester, '142_study_choice');
    await reset(tester, db);

    db = await start(tester, textScale: 2);
    await tapText(tester, '오늘 학습 시작');
    await shot(tester, '143_study_large_text');
    await reset(tester, db);
  });

  testWidgets('capture, review, a playlist, settings, 정보', (tester) async {
    var db = await start(tester, words: false);
    await tapText(tester, '페이지 등록');
    await shot(tester, '144_capture');
    await tapText(tester, 'DAY 01 자연, 몸');
    await shot(tester, '145_review');
    await reset(tester, db);

    db = await start(tester);
    await tapText(tester, '자연');
    await shot(tester, '146_playlist');
    await tester.tap(find.byKey(const ValueKey('word-w0')));
    await shot(tester, '147_playlist_word_modes');
    await reset(tester, db);

    db = await start(tester);
    await waitFor(tester, find.byTooltip('설정'));
    await tester.tap(find.byTooltip('설정'));
    await shot(tester, '148_settings');
    await reset(tester, db);

    db = await start(tester);
    await waitFor(tester, find.byTooltip('정보'));
    await tester.tap(find.byTooltip('정보'));
    await shot(tester, '149_about');
    await reset(tester, db);
  });
}
