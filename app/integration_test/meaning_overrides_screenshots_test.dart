// 시오리 보정 (the meaning overrides) on iPhone 17 Pro, with the app's
// dictionary assets: the 정보 screen's card (light and dark), and on the word
// editor a saved word's dictionary meaning that is off with the corrected
// meaning offered by 사전에서 다시 찾기 (the saved meaning stays until it is
// picked). One everyday word, in-memory database.
//
//   cd app && flutter drive -d <iPhone 17 Pro simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/meaning_overrides_screenshots_test.dart
//
// Screenshots land in docs/screenshots/ (210–212). Needs app/assets/dict/
// ko-glossary.*, jmdict-full-lean.* and meaning-overrides.*
// (tools/dict/build_meaning_overrides.py).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (unpacking the dictionaries takes a few
  /// seconds).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  /// A playlist with 本 saved under the meaning the dictionary gave before.
  Future<String> seed(ShioriDatabase db) async {
    final service = LibraryService(
      library: DriftLibraryRepository(db),
      clock: FixedClock(DateTime(2026, 11, 14, 9)),
    );
    final added = await service.addDraft(
      const CaptureDraft(
        entries: [
          CapturedEntry(
            headword: '本',
            readings: ['ほん'],
            pos: PartOfSpeech.noun,
            meaning: '그루',
          ),
        ],
      ),
      to: const NewPlaylist('시오리 보정'),
    );
    return added.playlist.id;
  }

  Future<(ShioriDatabase, String)> start(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    final database = ShioriDatabase.memory();
    final listId = await seed(database);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          onboardingStoreProvider.overrideWithValue(InMemoryOnboardingStore()),
        ],
        child: const ShioriApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await waitFor(tester, find.text('오늘'));
    return (database, listId);
  }

  Future<void> reset(WidgetTester tester, ShioriDatabase database) async {
    await tester.pumpWidget(const SizedBox());
    await database.close();
    tester.platformDispatcher.clearAllTestValues();
  }

  Future<void> aboutCard(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    final card = find.text('시오리 보정');
    for (var i = 0; i < 60 && card.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await waitFor(tester, card);
    await Scrollable.ensureVisible(tester.element(card), alignment: 0.12);
    await shot(tester, name);
  }

  testWidgets('시오리 보정: 정보 card and the editor\'s suggestion', (tester) async {
    var (db, listId) = await start(tester);
    await aboutCard(tester, '210_about_overrides');
    await reset(tester, db);

    (db, listId) = await start(tester, brightness: Brightness.dark);
    await aboutCard(tester, '211_about_overrides_dark');
    await reset(tester, db);

    (db, listId) = await start(tester);
    unawaited(
      pushScreen<void>(
        tester.element(find.byType(Navigator).first),
        PlaylistScreen(playlistId: listId),
      ),
    );
    await waitFor(tester, find.text('本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('本 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고치기').first);
    await tester.pumpAndSettle();
    // The dictionaries open in the background: ask again until they answer.
    await waitFor(tester, find.text('사전에서 다시 찾기'));
    final chip = find.widgetWithText(ActionChip, '책');
    for (var i = 0; i < 30 && chip.evaluate().isEmpty; i++) {
      await tester.tap(find.text('사전에서 다시 찾기'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(chip, findsOneWidget);
    await shot(tester, '212_edit_override_suggestion');
    await reset(tester, db);
  });
}
