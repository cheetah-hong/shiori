// Checks on a simulator that words and learning state outlive the app process.
// Uses the real database file (ShioriDatabase.file over appDatabaseFile())
// and a synthetic sample page.
//
//   cd app
//   xcrun simctl uninstall <simulator> com.nihongoapp.shiori.dev   # start empty (dev flavor)
//   flutter drive -d <simulator> --keep-app-running --driver=test_driver/integration_test.dart \
//     --target=integration_test/persistence_test.dart \
//     --dart-define=SHIORI_PERSISTENCE_STEP=save
//   xcrun simctl terminate <simulator> com.nihongoapp.shiori.dev
//   flutter drive ... (same) --dart-define=SHIORI_PERSISTENCE_STEP=reopen
//
// Study again (its own empty start, like save): the restudy step stores three
// made-up learned words, studies the cards brought forward from home (더
// 학습하기, one 다시 학습) and makes one word new again from the playlist;
// terminate, then restudy-reopen reads both back.
//
// Upgrade check: run the save step with an older build (an older checkout,
// schema v3), then, without uninstalling, the upgrade step with this build.
// Playlists are new in schema v4, so the older file's words and learning
// records cannot carry over to one: opening it upgrades to an empty v4
// database instead (user_version 4, no playlists, no words) rather than
// keeping anything from the old schema.
//
// Screenshots land in docs/screenshots/ (see test_driver/integration_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/app_database.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

const _step = String.fromEnvironment('SHIORI_PERSISTENCE_STEP');

/// The example-page sample: its word list and the words of its example
/// sentences. How many words the page gives depends on the dictionary and
/// the extraction rules, so the steps read the counts off the screen.
const _sampleDetail = 'DAY 20 여행·교통';

final _addButton = RegExp(r'^단어 (\d+)개 추가$');
final _startButton = RegExp(r'^오늘 학습 시작 · (\d+)장$');
final _knownToday = RegExp(r'^오늘 (\d+)개 외움$');

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

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool last = false,
  }) async {
    final finder = last ? find.text(text).last : find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<ShioriDatabase> pumpApp(WidgetTester tester) async {
    final database = ShioriDatabase.file(await appDatabaseFile());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    return database;
  }

  /// The number in the one text on screen that matches [pattern].
  Future<int> countOnScreen(WidgetTester tester, RegExp pattern) async {
    final finder = find.textContaining(pattern);
    await waitFor(tester, finder);
    final text = tester.widget<Text>(finder.first).data!;
    return int.parse(pattern.firstMatch(text)!.group(1)!);
  }

  /// How many words adding the sample saves into an empty library: the
  /// sample read again with the app's own extractor and dictionaries.
  Future<int> sampleWordCount(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShioriApp)),
    );
    await container.read(bundledDictionaryProvider.future);
    await container.read(bundledGlossaryProvider.future);
    final sample = devSamples.singleWhere((s) => s.detail == _sampleDetail);
    final scan = await container
        .read(sampleRecognizerProvider)
        .recognize(sample.image);
    final draft = await pageDraft(
      container.read(generalExtractorProvider),
      scan,
    );
    return draft.entries
        .where((e) => e.included && e.headword.trim().isNotEmpty)
        .length;
  }

  /// The words of the one playlist, in its order (the order studied).
  Future<List<Word>> playlistWords(ShioriDatabase database) async {
    final library = DriftLibraryRepository(database);
    final playlist = (await library.playlists()).single;
    return library.words(playlistId: playlist.id);
  }

  testWidgets('save a page and study it', (tester) async {
    final database = await pumpApp(tester);
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));

    await tapText(tester, '페이지 등록');
    await tapText(tester, _sampleDetail);
    final added = await countOnScreen(tester, _addButton);
    await tapText(tester, '단어 $added개 추가');
    // A fresh database has no playlist yet: the new-playlist form is already
    // open with 내 단어장 filled in.
    await waitFor(tester, find.text('만들고 추가'));
    await tapText(tester, '만들고 추가');

    // Today's session: every new word, up to the daily goal.
    final cards = await countOnScreen(tester, _startButton);
    final goal = const StudySettings().dailyGoal;
    expect(cards, added < goal ? added : goal);
    await tapText(tester, '오늘 학습 시작 · $cards장');
    await tapText(tester, '다시 학습');
    for (var i = 0; i < cards; i++) {
      await tapText(tester, '알고있음');
    }
    expect(find.text('오늘 학습 끝'), findsOneWidget);
    await tapText(tester, '확인');
    await waitFor(tester, find.text('오늘 $cards개 외움'));
    expect(await DriftLibraryRepository(database).words(), hasLength(added));
  }, skip: _step != 'save');

  testWidgets('after a restart the words and memory levels are back', (
    tester,
  ) async {
    final database = await pumpApp(tester);
    final cards = await countOnScreen(tester, _knownToday);
    expect(find.text('먼저 페이지를 등록해 주세요'), findsNothing);

    // Read back from the file: every word of the sample; of the cards
    // studied, the retried one at level 2 and the others at level 4; one
    // press more than cards (one 다시 학습, then 알고있음 for each card).
    final words = await DriftLibraryRepository(database).words();
    final reviews = DriftReviewRepository(database);
    final levels = (await reviews.cards()).values.map((c) => c.level).toList()
      ..sort();
    expect(words, hasLength(await sampleWordCount(tester)));
    expect(cards, greaterThan(0));
    expect(levels, [2, for (var i = 1; i < cards; i++) 4]);
    expect((await reviews.logs()).length, cards + 1);

    await tapText(tester, '내 단어장');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await shot(tester, '16_textbook_after_restart');
  }, skip: _step != 'reopen');

  testWidgets('study again: 더 학습하기 and 처음부터 다시 학습', (tester) async {
    // Three made-up words, all learned and none due yet.
    final seeded = ShioriDatabase.file(await appDatabaseFile());
    final now = DateTime.now();
    await LibraryService(
      library: DriftLibraryRepository(seeded),
      clock: const SystemClock(),
    ).addDraft(
      CaptureDraft(
        entries: [
          for (final (head, kana, meaning) in _madeUp)
            CapturedEntry(
              headword: head,
              readings: [kana],
              pos: null,
              meaning: meaning,
            ),
        ],
      ),
      to: const NewPlaylist('내 단어장'),
    );
    final seededWords = await playlistWords(seeded);
    for (final (i, level) in [2, 4, 3].indexed) {
      await DriftReviewRepository(seeded).saveCard(
        ReviewCard(
          wordId: seededWords[i].id,
          level: level,
          dueAt: now.add(Duration(days: level * 3)),
          lastReviewedAt: now,
          reviewCount: 1,
        ),
      );
    }
    await seeded.close();

    final database = await pumpApp(tester);
    final words = await playlistWords(database);
    final reviews = DriftReviewRepository(database);

    // Nothing is due: home offers the cards brought forward, lowest level
    // first.
    await waitFor(tester, find.text('더 학습하기'));
    await tapText(tester, '더 학습하기');
    await waitFor(tester, find.text(words[0].headword));
    await tapText(tester, '다시 학습');
    await tester.tap(find.byTooltip('학습 그만하기'));
    await tester.pumpAndSettle();

    await tapText(tester, '내 단어장');
    await tester.tap(find.byTooltip('${words[1].headword} 메뉴'));
    await tester.pumpAndSettle();
    await tapText(tester, '처음부터 다시 학습');
    await waitFor(tester, find.text('「${words[1].headword}」 새 단어로 돌렸어요'));

    expect((await reviews.card(words[0].id))?.level, 1);
    expect(await reviews.card(words[1].id), isNull);
    expect((await reviews.logs()).length, 1);
  }, skip: _step != 'restudy');

  testWidgets(
    'after a restart the studied-again words are as left',
    (tester) async {
      final database = await pumpApp(tester);
      await waitFor(tester, find.text('오늘 학습 시작 · 2장'));

      final words = await playlistWords(database);
      final reviews = DriftReviewRepository(database);
      final again = await reviews.card(words[0].id);
      expect(again?.level, 1);
      expect(again?.lapseCount, 1);
      expect(await reviews.card(words[1].id), isNull, reason: 'a new word');
      expect((await reviews.card(words[2].id))?.level, 3, reason: 'untouched');
      expect((await reviews.logs()).length, 1, reason: 'the 다시 학습 press');
    },
    skip: _step != 'restudy-reopen',
  );

  testWidgets(
    'a file from the older schema opens as an empty v4 database',
    (tester) async {
      final database = await pumpApp(tester);
      await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 4);
      expect(database.schemaVersion, 4);

      final library = DriftLibraryRepository(database);
      expect(await library.playlists(), isEmpty);
      expect(await library.words(), isEmpty);
      final reviews = DriftReviewRepository(database);
      expect(await reviews.cards(), isEmpty);
      expect(await reviews.logs(), isEmpty);

      await waitFor(tester, find.text('페이지를 등록하고 재생목록에 단어를 모아 보세요'));
    },
    skip: _step != 'upgrade',
  );
}

/// Made-up words (headword, reading, meaning) for the restudy steps.
const _madeUp = [
  ('試語甲', 'しごこう', '시험 낱말 갑'),
  ('試語乙', 'しごおつ', '시험 낱말 을'),
  ('試語丙', 'しごへい', '시험 낱말 병'),
];
