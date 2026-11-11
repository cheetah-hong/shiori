// Tatoeba example sentences on a simulator: cards whose page printed no
// example show the sentence of the word's dictionary entry (Korean, else
// English) with 「예문: Tatoeba」 and play it with the real engine; the 정보
// card and the licence entry. The assets are unpacked on the device.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/examples_screenshots_test.dart
//
// Needs app/assets/dict/ (JMdict, examples: tools/dict/build_app_asset.py,
// build_examples.py), the voice and accent assets and the engine.
// Screenshots land in docs/screenshots/. In-memory database; the cards are
// two common words added by the test, not from a page.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/about/examples_card.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<int> soundFiles() async {
    final dir = Directory(
      '${(await getApplicationCacheDirectory()).path}/speech',
    );
    if (!dir.existsSync()) return 0;
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.wav'))
        .length;
  }

  testWidgets('filled examples: Korean, English, the source, credits', (
    tester,
  ) async {
    registerExampleLicense();
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    final at = DateTime(2026, 11, 12, 9);
    final words = [
      Word(
        id: 'ex-1',
        headword: '傘',
        readings: const ['かさ'],
        meaning: '우산',
        pos: PartOfSpeech.noun,
        createdAt: at,
      ),
      Word(
        id: 'ex-2',
        headword: '毎朝',
        readings: const ['まいあさ'],
        meaning: '매일 아침',
        pos: PartOfSpeech.noun,
        createdAt: at.add(const Duration(minutes: 1)),
      ),
    ];
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final library = container.read(libraryRepositoryProvider);
    await library.insertWords(words);
    await library.savePlaylist(
      Playlist(id: 'ex', name: '예문 시험', createdAt: at, position: 0),
    );
    await library.addToPlaylist('ex', ['ex-1', 'ex-2'], at: at);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ShioriApp()),
    );
    await tester.pumpAndSettle();

    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    await tap(tester, find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('傘'));
    // The sentence of 傘's entry, with its source (the asset unpacks first).
    await waitFor(tester, find.text('예문: Tatoeba'));
    await shot(tester, '105_study_tatoeba_example');

    // Played through the example path with the real engine.
    final before = await soundFiles();
    await tap(tester, find.byTooltip('예문 듣기'));
    await waitFor(tester, find.byTooltip('예문 듣기'));
    expect(find.byType(SnackBar), findsNothing);
    expect(await soundFiles(), before + 1);
    await tap(tester, find.text('뜻 보기'));
    await tester.pumpAndSettle();
    await shot(tester, '106_study_tatoeba_korean');

    // Next card: a sentence with an English translation only.
    await tap(tester, find.textContaining('알고있음').first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('毎朝'));
    await waitFor(tester, find.text('예문: Tatoeba · 영어 번역'));
    await tap(tester, find.text('뜻 보기'));
    await tester.pumpAndSettle();
    await shot(tester, '107_study_tatoeba_english');

    // 정보: the Tatoeba card.
    await tap(tester, find.byTooltip('학습 그만하기'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byTooltip('정보'));
    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();
    final card = find.text('Tatoeba');
    await tester.scrollUntilVisible(card, 200);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -40));
    await shot(tester, '108_about_examples');

    // The licence page entry.
    await tester.scrollUntilVisible(find.text('오픈소스 라이선스'), 300);
    await tap(tester, find.text('오픈소스 라이선스'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('시오리'));
    final entry = find.text('Tatoeba');
    for (var i = 0; i < 60 && entry.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(entry.first);
    await tester.pumpAndSettle();
    await tester.tap(entry.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('CC BY 2.0 FR'), findsWidgets);
    await shot(tester, '109_license_examples');
  });
}
