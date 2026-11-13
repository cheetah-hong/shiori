// The screens on the iPhones the app supports, after fitting them to small
// screens and large text and quieting them down, in Pretendard JP. One run
// per simulator; SCREEN picks that phone's shots:
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screen_fit_screenshots_test.dart \
//     --dart-define=SCREEN=se        # se | mini | 17 | promax
//
// Screenshots land in docs/screenshots/ (150–165). In-memory database,
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

const _screen = String.fromEnvironment('SCREEN', defaultValue: 'se');

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

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // Scrolls the page down until a row out of sight is built.
    final page = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty || page.evaluate().isEmpty) break;
      await tester.drag(page.first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tap(tester, find.textContaining(text));

  Future<ShioriDatabase> seeded(StudyMode mode) async {
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
    await DriftStudyPreferencesRepository(database).save(
      StudyPreferences(mode: mode, dailyGoal: DailyGoal.ten, shuffle: false),
    );
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
    final database = words ? await seeded(mode) : ShioriDatabase.memory();
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

  Future<void> home(
    WidgetTester tester,
    String name, {
    double scale = 1,
  }) async {
    final db = await start(tester, textScale: scale);
    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    await shot(tester, name);
    await reset(tester, db);
  }

  Future<void> study(
    WidgetTester tester,
    String name, {
    StudyMode mode = StudyMode.meaning,
    double scale = 1,
    String? turn,
  }) async {
    final db = await start(tester, mode: mode, textScale: scale);
    await tapText(tester, '오늘 학습 시작');
    await tester.pump(const Duration(seconds: 1));
    // 듣고 맞히기 makes the word's sound first; its button reads 불러오는 중
    // until then.
    if (mode == StudyMode.listening) {
      await waitFor(tester, find.text('다시 듣기'));
    }
    if (turn != null) await tapText(tester, turn);
    await shot(tester, name);
    await reset(tester, db);
  }

  testWidgets('SE (4.7″)', (tester) async {
    await home(tester, '150_se_home');
    await home(tester, '151_se_home_large_text', scale: 3.1);
    await study(tester, '152_se_study_meaning');
    await study(tester, '153_se_study_large_text', scale: 3.1, turn: '뜻 보기');

    var db = await start(tester, words: false);
    await tapText(tester, '페이지 등록');
    await tapText(tester, 'DAY 01 자연, 몸');
    await shot(tester, '154_se_review');
    await reset(tester, db);

    db = await start(tester, words: false, firstLaunch: true);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('건너뛰기'));
    await shot(tester, '155_se_onboarding');
    await reset(tester, db);
  }, skip: _screen != 'se');

  testWidgets('13 mini (5.4″)', (tester) async {
    var db = await start(tester, brightness: Brightness.dark);
    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    await shot(tester, '156_mini_home_dark');
    await reset(tester, db);

    await study(tester, '157_mini_listening', mode: StudyMode.listening);
    await study(
      tester,
      '158_mini_choice_answered',
      mode: StudyMode.choice,
      turn: '물',
    );

    db = await start(tester);
    await tapText(tester, '뜻 맞히기');
    await shot(tester, '159_mini_mode_sheet');
    await reset(tester, db);

    db = await start(tester);
    await tap(tester, find.text('자연'));
    await shot(tester, '160_mini_playlist');
    await reset(tester, db);

    db = await start(tester);
    await tap(tester, find.byTooltip('설정'));
    await shot(tester, '161_mini_settings');
    await reset(tester, db);
  }, skip: _screen != 'mini');

  testWidgets('17 (6.3″)', (tester) async {
    var db = await start(tester);
    await tapText(tester, '오늘 학습 시작');
    for (var i = 0; i < 14; i++) {
      if (find.text('오늘 학습 끝').evaluate().isNotEmpty) break;
      final show = find.text('뜻 보기');
      if (show.evaluate().isNotEmpty) await tap(tester, show);
      await tap(tester, find.text('알고있음'));
    }
    await waitFor(tester, find.text('오늘 학습 끝'));
    await shot(tester, '162_17_session_done');
    await reset(tester, db);

    db = await start(tester, words: false, textScale: 3.1);
    await tapText(tester, '페이지 등록');
    await shot(tester, '163_17_capture_large_text');
    await reset(tester, db);
  }, skip: _screen != '17');

  testWidgets('17 Pro Max (6.9″)', (tester) async {
    await home(tester, '164_promax_home');
    await study(
      tester,
      '165_promax_recall_large_text',
      mode: StudyMode.recall,
      scale: 3.1,
      turn: '일본어 보기',
    );
  }, skip: _screen != 'promax');
}
