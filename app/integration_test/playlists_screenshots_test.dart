// Playlists on a simulator, synthetic sample pages only: the empty home, the
// review's 「단어 N개 추가」, the playlist picker (a new playlist, then the
// lists with 「이미 있음」), a word already in the library, the playlist
// screen, choosing what to study, the settings and the edit screen.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/playlists_screenshots_test.dart
//
// Screenshots land in docs/screenshots/. Needs app/assets/dict/ (JMdict and
// the Korean glossary). In-memory database: the simulator's data is not
// touched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/capture/evidence_tile.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// Pumps until [finder] shows up (unpacking takes a few seconds).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
  }

  Future<void> openSample(WidgetTester tester, DevSample sample) async {
    await tester.tap(find.text('페이지 등록'));
    await tester.pumpAndSettle();
    final row = find.text('${sample.page}쪽 · ${sample.layout}');
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await waitFor(tester, find.byKey(const ValueKey('review-heading')));
  }

  final addButton = find.textContaining(RegExp(r'^단어 \d+개 추가$'));

  testWidgets('playlists: add, pick, study scope, settings', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.text('먼저 페이지를 등록해 주세요'));
    // The dictionaries unpack in the background; the 정보 screen waits.
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('JMdict 날짜'));
    await back(tester);
    await shot(tester, '54_home_no_playlists');

    // First page: the review, then a new playlist from the picker.
    await openSample(tester, devSamples.first);
    await shot(tester, '55_review_add_button');
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await shot(tester, '56_picker_first_playlist');
    await tester.tap(find.text('만들고 추가'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining("'내 단어장'에 단어"));

    // A second page into a second playlist.
    await openSample(tester, devSamples[2]);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 재생목록'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '재생목록 이름'),
      '여행 단어',
    );
    await tester.pumpAndSettle();
    await shot(tester, '57_picker_new_playlist_name');
    await tester.tap(find.text('만들고 추가'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining("'여행 단어'에 단어"));
    await shot(tester, '58_home_playlists');

    // The first page again: its words are in the library already.
    await openSample(tester, devSamples.first);
    await tester.scrollUntilVisible(find.text(inLibraryLabel).first, 200);
    await shot(tester, '59_review_in_library');
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await shot(tester, '60_picker_already_in');
    await tester.tap(find.text('여행 단어'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.textContaining("'여행 단어'에 단어"));

    // The playlist screen and a word's menu.
    await tester.tap(find.text('내 단어장'));
    await tester.pumpAndSettle();
    await shot(tester, '61_playlist_screen');
    await tester.tap(find.byTooltip(RegExp(r' 메뉴$')).at(1));
    await tester.pumpAndSettle();
    await shot(tester, '62_playlist_word_menu');
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await back(tester);

    // What to study, the settings, the edit screen.
    await tester.tap(find.text('재생목록 골라 학습'));
    await tester.pumpAndSettle();
    await shot(tester, '63_study_scope_sheet');
    await tester.tap(find.byKey(const ValueKey('scope-all')));
    await tester.pumpAndSettle();
    await shot(tester, '64_study_all');
    await tester.tap(find.byTooltip('학습 그만하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await shot(tester, '65_settings');
    await back(tester);

    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();
    await shot(tester, '66_playlists_edit');
  });
}
