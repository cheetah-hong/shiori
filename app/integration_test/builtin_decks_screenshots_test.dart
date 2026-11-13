// 기본 단어장 on iPhone 17 Pro: the deck list (light, dark, large text, with
// two decks in), a deck, the confirmation, what went in, the empty home's way
// in, and the 정보 credit. The decks keep their names and levels but hold a
// few made-up everyday words with made-up dictionary data: the word lists
// themselves stay out of the public repository and its pictures.
//
//   cd app && flutter drive -d <iPhone 17 Pro simulator> --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/builtin_decks_screenshots_test.dart
//
// Screenshots land in docs/screenshots/ (180–188). In-memory database.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori/features/decks/decks_screen.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';
import 'package:shiori/shared/navigation.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// Per level: (headword, reading, meaning or null for one the made-up
/// dictionary has none for).
const _levels = {
  'N5': [
    ('雨傘', 'あまがさ', '우산'),
    ('小道', 'こみち', '오솔길'),
    ('木陰', 'こかげ', '나무 그늘'),
    ('星空', 'ほしぞら', '별하늘'),
    ('野原', 'のはら', '들판'),
    ('小川', 'おがわ', '시내'),
    ('夜空', 'よぞら', '밤하늘'),
    ('綿雲', 'わたぐも', null),
  ],
  'N4': [
    ('朝霧', 'あさぎり', '아침 안개'),
    ('若葉', 'わかば', '어린잎'),
    ('春風', 'はるかぜ', '봄바람'),
    ('夏草', 'なつくさ', '여름풀'),
    ('山道', 'やまみち', '산길'),
    ('坂道', 'さかみち', '비탈길'),
  ],
  'N3': [
    ('雪だるま', 'ゆきだるま', '눈사람'),
    ('稲妻', 'いなずま', '번개'),
    ('冬空', 'ふゆぞら', '겨울 하늘'),
    ('風鈴', 'ふうりん', '풍경'),
    ('海辺', 'うみべ', '바닷가'),
  ],
  'N2': [
    ('木漏れ日', 'こもれび', '나뭇잎 사이 햇살'),
    ('雨宿り', 'あまやどり', '비를 피함'),
    ('秋晴れ', 'あきばれ', '가을의 맑은 날씨'),
    ('朝焼け', 'あさやけ', '아침놀'),
    ('初雪', 'はつゆき', '첫눈'),
  ],
  'N1': [
    ('夕凪', 'ゆうなぎ', '저녁뜸'),
    ('霜柱', 'しもばしら', '서릿발'),
    ('雪解け', 'ゆきどけ', '눈 녹음'),
    ('縁日', 'えんにち', '잿날'),
    ('桜並木', 'さくらなみき', '벚나무 가로수'),
  ],
};

int _entry(String level, int i) =>
    9500000 + 100 * (5 - int.parse(level[1])) + i;

final _set = BuiltinDeckSet(
  edition: '2026-11-13',
  sources: const [
    DeckSource(
      name: 'JLPT Resources',
      author: 'Jonathan Waller',
      license: 'CC BY',
      licenseUrl: 'https://www.tanos.co.uk/jlpt/sharing/',
      url: 'https://www.tanos.co.uk/jlpt/',
    ),
    DeckSource(
      name: 'yomitan-jlpt-vocab',
      author: 'Stephen Kraus',
      license: 'CC BY-SA 4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      url: 'https://github.com/stephenmk/yomitan-jlpt-vocab',
    ),
  ],
  decks: [
    for (final MapEntry(key: level, value: words) in _levels.entries)
      BuiltinDeck(
        id: 'jlpt-${level.toLowerCase()}',
        name: 'JLPT $level 대비',
        level: level,
        words: [
          for (final (i, (h, r, _)) in words.indexed)
            DeckWord(headword: h, reading: r, entryId: _entry(level, i)),
        ],
      ),
  ],
);

/// One sense per made-up word.
final class _Glossary implements KoreanGlossary {
  const _Glossary();

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async => [
    for (final words in _levels.values)
      for (final (h, _, m) in words)
        if (h == headword && m != null)
          KoreanSense(words: [m], source: GlossarySource.krdict),
  ];

  @override
  List<GlossarySourceInfo> get sources => const [];
}

final _dictionaries = DeckDictionaries(
  lexicon: InMemoryLexicon([
    for (final MapEntry(key: level, value: words) in _levels.entries)
      for (final (i, (h, r, _)) in words.indexed)
        LexiconWord(
          id: _entry(level, i),
          kanji: [h],
          readings: [r],
          pos: const ['n'],
        ),
  ]),
  glossary: const _Glossary(),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 400 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<ShioriDatabase> start(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    final database = ShioriDatabase.memory();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          onboardingStoreProvider.overrideWithValue(InMemoryOnboardingStore()),
          builtinDecksProvider.overrideWith((ref) async => _set),
          deckDictionariesProvider.overrideWith((ref) async => _dictionaries),
        ],
        child: const ShioriApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await waitFor(tester, find.text('오늘'));
    return database;
  }

  Future<void> reset(WidgetTester tester, ShioriDatabase database) async {
    await tester.pumpWidget(const SizedBox());
    await database.close();
    tester.platformDispatcher.clearAllTestValues();
  }

  BuildContext homeContext(WidgetTester tester) =>
      tester.element(find.byType(Navigator).first);

  testWidgets('기본 단어장', (tester) async {
    // The empty home with its way in, then the decks.
    var db = await start(tester);
    await waitFor(tester, find.text('기본 단어장 둘러보기'));
    await shot(tester, '186_decks_empty_home');
    await tapText(tester, '기본 단어장 둘러보기');
    await waitFor(tester, find.text('JLPT N1 대비'));
    await shot(tester, '180_decks_list');

    // A deck, asked first, the words going in, what went in.
    await tapText(tester, 'JLPT N5 대비');
    await shot(tester, '182_deck_n5');
    await tapText(tester, '재생목록에 추가');
    await shot(tester, '183_deck_confirm');
    await tester.tap(find.text('넣기'));
    await waitFor(tester, find.textContaining('를 넣었어요'));
    await shot(tester, '185_deck_added');

    // The largest deck: its words go in within a moment (too fast to catch
    // the progress line), then the list says which decks are in.
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tapText(tester, 'JLPT N1 대비');
    await tapText(tester, '재생목록에 추가');
    await tester.tap(find.text('넣기'));
    await waitFor(tester, find.textContaining('를 넣었어요'));
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('추가됨'));
    await shot(tester, '184_decks_list_added');
    await reset(tester, db);

    // Dark and large text.
    db = await start(tester, brightness: Brightness.dark);
    unawaited(pushScreen<void>(homeContext(tester), const DecksScreen()));
    await waitFor(tester, find.text('JLPT N1 대비'));
    await shot(tester, '181_decks_list_dark');
    await reset(tester, db);

    db = await start(tester, textScale: 2);
    unawaited(pushScreen<void>(homeContext(tester), const DecksScreen()));
    await waitFor(tester, find.text('JLPT N5 대비'));
    await shot(tester, '188_decks_list_large_text');
    await reset(tester, db);

    // 정보: the credit.
    db = await start(tester);
    unawaited(pushScreen<void>(homeContext(tester), const AboutScreen()));
    await waitFor(tester, find.widgetWithText(AppBar, '정보'));
    await tester.pump(const Duration(seconds: 1));
    final credit = find.text('JLPT 대비 단어 목록');
    await tester.scrollUntilVisible(
      credit,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 120));
    await shot(tester, '187_about_decks');
    await reset(tester, db);
  });
}
