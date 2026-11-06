// Pronunciation on a simulator or emulator: the word's speaker button with
// the real engine, the pitch line, an estimated accent, the example's
// speaker button and the 정보 credits.
//
//   cd app && flutter drive -d <simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/speech_screenshots_test.dart
//
// Needs the voice and accent assets (tools/voice/) and the engine. Screenshots
// land in docs/screenshots/. In-memory database, made-up words only.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/study/pitch_line.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Android draws through a platform surface that must be turned into an
  // image once per test before screenshots.
  var surfaceConverted = false;
  setUp(() => surfaceConverted = false);
  Future<void> shot(WidgetTester tester, String name) async {
    if (Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int tries = 600,
  }) async {
    for (var i = 0; i < tries && finder.evaluate().isEmpty; i++) {
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

  testWidgets('word and example sounds, pitch line, estimate, credits', (
    tester,
  ) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    final at = DateTime(2026, 11, 6, 21);
    // Two made-up cards: one the accent data has, one it has not.
    final words = [
      Word(
        id: 'tts-1',
        headword: '箸',
        readings: const ['はし'],
        meaning: '젓가락',
        pos: PartOfSpeech.noun,
        example: const Example(ja: '箸で食べます。', ko: '젓가락으로 먹습니다.'),
        createdAt: at,
      ),
      Word(
        id: 'tts-2',
        // A polite past form: no entry of its own in the accent data.
        headword: '食べました',
        readings: const ['たべました'],
        meaning: '먹었습니다',
        pos: PartOfSpeech.verb,
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
      Playlist(id: 'tts', name: '발음 시험', createdAt: at, position: 0),
    );
    await library.addToPlaylist('tts', ['tts-1', 'tts-2'], at: at);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ShioriApp()),
    );
    await tester.pumpAndSettle();

    await waitFor(tester, find.textContaining('오늘 학습 시작'));
    await tap(tester, find.textContaining('오늘 학습 시작'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('箸'));

    // The word, played with the real engine (no failure shown).
    await tap(tester, find.byTooltip('발음 듣기'));
    await waitFor(tester, find.byTooltip('발음 듣기'));
    expect(find.byType(SnackBar), findsNothing);
    expect(await soundFiles(), 1);
    await shot(tester, '80_study_word_speech');

    // The reading with its pitch line.
    await tap(tester, find.text('읽기 보기'));
    await tester.pumpAndSettle();
    await shot(tester, '81_study_pitch_line');

    // The example: made with the word's accent kept.
    await tap(tester, find.byTooltip('예문 듣기'));
    await waitFor(tester, find.byTooltip('예문 듣기'));
    expect(find.byType(SnackBar), findsNothing);
    expect(await soundFiles(), 2);
    await tap(tester, find.text('뜻 보기'));
    await tester.pumpAndSettle();
    await shot(tester, '82_study_example_speech');

    // Next card: a word the accent data does not have.
    await tap(tester, find.textContaining('알고있음').first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('食べました'));
    await tap(tester, find.text('읽기 보기'));
    await waitFor(tester, find.text('추정'));
    // The engine's guess is drawn as a line next to 「추정」.
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) => w is PitchLine && w.info.estimated && w.info.highs != null,
      ),
    );
    await tap(tester, find.byTooltip('발음 듣기'));
    await waitFor(tester, find.byTooltip('발음 듣기'));
    expect(find.byType(SnackBar), findsNothing);
    expect(await soundFiles(), 3);
    await shot(tester, '83_study_estimated_accent');
  });

  testWidgets('정보: the voice and accent data credits', (tester) async {
    final database = ShioriDatabase.memory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const ShioriApp(),
      ),
    );
    await waitFor(tester, find.byTooltip('정보'));
    await tap(tester, find.byTooltip('정보'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('발음'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The section from its label down, credit first.
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(find.text('발음'))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('VOICEVOX:四国めたん'), findsWidgets);
    await shot(tester, '84_about_voice_credits');
  });
}
