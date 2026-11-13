// B6·B7: 기본 단어장. The decks screen lists every deck with its word count
// and the list's source (never 「공식」); a deck shows its first words and
// adds to a playlist of its name after a confirmation, with the words being
// added, then how many went in and how many had no meaning; adding again
// fetches only the missing words; without dictionaries nothing is added.
// It opens from the empty home, the guide's last page and 재생목록 편집's
// 기본 단어장 button. The deck file, when built, reads as five decks.
// Made-up words only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/decks/decks_screen.dart';
import 'package:shiori/features/onboarding/onboarding_store.dart';
import 'package:shiori/features/playlists/playlist_screen.dart';
import 'package:shiori/features/playlists/playlists_screen.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/design.dart';
import '../support/harness.dart';

/// One sense per headword; [gate] holds every answer until completed.
final class _Glossary implements KoreanGlossary {
  _Glossary(this.byHeadword, {this.gate});

  final Map<String, String> byHeadword;
  final Completer<void>? gate;

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    await gate?.future;
    return [
      if (byHeadword[headword] case final String meaning)
        KoreanSense(words: [meaning], source: GlossarySource.krdict),
    ];
  }

  @override
  List<GlossarySourceInfo> get sources => const [];
}

final _lexicon = InMemoryLexicon(const [
  LexiconWord(id: 9000001, kanji: ['雨傘'], readings: ['あまがさ'], pos: ['n']),
  LexiconWord(id: 9000002, readings: ['ぽかぽか'], pos: ['adv']),
  LexiconWord(id: 9000005, kanji: ['夕凪'], readings: ['ゆうなぎ'], pos: ['n']),
  LexiconWord(id: 9000006, kanji: ['小道'], readings: ['こみち'], pos: ['n']),
  LexiconWord(id: 9000010, kanji: ['風車'], readings: ['かざぐるま'], pos: ['n']),
]);

const _meanings = {'雨傘': '우산', 'ぽかぽか': '따끈따끈', '小道': '오솔길', '風車': '바람개비'};

final _set = parseBuiltinDecks(
  jsonEncode({
    'format': 'shiori-decks',
    'version': 1,
    'edition': '2026-11-13',
    'sources': [
      {
        'name': '지어낸 목록',
        'author': '지어낸 저자',
        'license': 'CC BY',
        'licenseUrl': 'https://example.com/license',
        'url': 'https://example.com/list',
      },
    ],
    'decks': [
      {
        'id': 'jlpt-n5',
        'name': 'JLPT N5 대비',
        'level': 'N5',
        'words': [
          {'h': '雨傘', 'r': 'あまがさ', 'e': 9000001},
          {'h': 'ぽかぽか', 'r': 'ぽかぽか', 'e': 9000002},
          {'h': '夕凪', 'r': 'ゆうなぎ', 'e': 9000005},
        ],
      },
      {
        'id': 'jlpt-n4',
        'name': 'JLPT N4 대비',
        'level': 'N4',
        'words': [
          {'h': '小道', 'r': 'こみち', 'e': 9000006},
          {'h': '風車', 'r': 'かざぐるま', 'e': 9000010},
        ],
      },
    ],
  }),
);

List<Override> _decks({KoreanGlossary? glossary, bool dictionaries = true}) => [
  builtinDecksProvider.overrideWith((ref) async => _set),
  deckDictionariesProvider.overrideWith(
    (ref) async => dictionaries
        ? DeckDictionaries(
            lexicon: _lexicon,
            glossary: glossary ?? _Glossary(_meanings),
          )
        : null,
  ),
];

Future<void> _openDecks(
  WidgetTester tester,
  TestBlocks blocks, {
  KoreanGlossary? glossary,
  bool dictionaries = true,
}) async {
  usePhoneSize(tester);
  await tester.pumpWidget(
    screen(
      blocks,
      const DecksScreen(),
      extra: _decks(glossary: glossary, dictionaries: dictionaries),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openN5(WidgetTester tester) async {
  await tester.tap(find.text('JLPT N5 대비'));
  await tester.pumpAndSettle();
}

/// Taps the bar's main button and confirms with [confirm].
Future<void> _add(
  WidgetTester tester, {
  String button = '재생목록에 추가',
  String confirm = '넣기',
  bool settle = true,
}) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  await tester.tap(find.text(confirm));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<List<Word>> _wordsOf(TestBlocks blocks, String name) async {
  final list = (await blocks.library.playlists()).singleWhere(
    (p) => p.name == name,
  );
  return blocks.library.words(playlistId: list.id);
}

/// No text on screen says 「공식」.
void _neverOfficial() {
  for (final e in find.byType(Text).evaluate()) {
    final text =
        (e.widget as Text).data ??
        (e.widget as Text).textSpan?.toPlainText() ??
        '';
    expect(text, isNot(contains('공식')));
  }
}

void main() {
  testWidgets('B7 기본 단어장 lists each deck with its word count and the '
      'source of the lists', (tester) async {
    await _openDecks(tester, TestBlocks());

    expect(find.widgetWithText(AppBar, '기본 단어장'), findsOneWidget);
    expect(find.text('JLPT N5 대비'), findsOneWidget);
    expect(find.text('단어 3개'), findsOneWidget);
    expect(find.text('JLPT N4 대비'), findsOneWidget);
    expect(find.text('단어 2개'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('지어낸 저자'), 200);
    expect(find.textContaining('지어낸 저자'), findsOneWidget);
    expect(find.textContaining('주최 측이 낸 목록이 아니에요'), findsOneWidget);
    _neverOfficial();
  });

  testWidgets('B7 a deck shows its first words, the source and 재생목록에 추가', (
    tester,
  ) async {
    await _openDecks(tester, TestBlocks());
    await _openN5(tester);

    expect(find.widgetWithText(AppBar, 'JLPT N5 대비'), findsOneWidget);
    expect(find.text('雨傘'), findsOneWidget);
    expect(find.text('あまがさ'), findsOneWidget);
    expect(find.text('ぽかぽか'), findsOneWidget);
    expect(find.text('재생목록에 추가'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('지어낸 저자'), 200);
    expect(find.textContaining('지어낸 저자'), findsOneWidget);
    expect(find.textContaining('오늘 학습'), findsWidgets);
    _neverOfficial();
  });

  testWidgets('B7 adding: asked first, then the words go in and the words '
      'without a meaning are counted', (tester) async {
    final blocks = TestBlocks();
    await _openDecks(tester, blocks);
    await _openN5(tester);

    await tester.tap(find.text('재생목록에 추가'));
    await tester.pumpAndSettle();
    expect(find.text('「JLPT N5 대비」에 넣을까요?'), findsOneWidget);
    expect(find.textContaining('단어 3개'), findsWidgets);
    expect(find.text('취소'), findsOneWidget);
    await tester.tap(find.text('넣기'));
    await tester.pumpAndSettle();

    expect(find.text('단어 2개를 넣었어요'), findsOneWidget);
    expect(find.textContaining('뜻을 찾지 못한 1개는 넣지 않았어요'), findsOneWidget);
    final words = await _wordsOf(blocks, 'JLPT N5 대비');
    expect([for (final w in words) w.headword], ['雨傘', 'ぽかぽか']);
    expect(words.first.meaning, '우산');
    expect(words.first.readings, ['あまがさ']);
    expect(words.last.readings, isEmpty);
  });

  testWidgets('B7 cancel adds nothing', (tester) async {
    final blocks = TestBlocks();
    await _openDecks(tester, blocks);
    await _openN5(tester);

    await _add(tester, confirm: '취소');

    expect(await blocks.library.playlists(), isEmpty);
    expect(find.text('재생목록에 추가'), findsOneWidget);
  });

  testWidgets('B7 while the words go in: what is being added, and a '
      'progress line', (tester) async {
    final gate = Completer<void>();
    final blocks = TestBlocks();
    await _openDecks(
      tester,
      blocks,
      glossary: _Glossary(_meanings, gate: gate),
    );
    await _openN5(tester);

    await _add(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('단어 3개를 넣고 있어요'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('단어 2개를 넣었어요'), findsOneWidget);
  });

  testWidgets('B7 added: the list says so, 빠진 단어 채우기 adds nothing twice', (
    tester,
  ) async {
    final blocks = TestBlocks();
    await _openDecks(tester, blocks);
    await _openN5(tester);
    await _add(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('추가됨'), findsOneWidget);
    await _openN5(tester);
    await _add(tester, button: '빠진 단어 채우기', confirm: '채우기');

    expect(find.text('새로 넣은 단어가 없어요'), findsOneWidget);
    expect(await blocks.library.playlists(), hasLength(1));
    expect(await _wordsOf(blocks, 'JLPT N5 대비'), hasLength(2));
  });

  testWidgets('B7 재생목록 열기 after adding opens the playlist', (tester) async {
    final blocks = TestBlocks();
    await _openDecks(tester, blocks);
    await _openN5(tester);
    await _add(tester);

    await tester.tap(find.text('재생목록 열기'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistScreen), findsOneWidget);
    expect(find.text('雨傘'), findsWidgets);
  });

  testWidgets('B7 without the dictionaries: says so, adds nothing', (
    tester,
  ) async {
    final blocks = TestBlocks();
    await _openDecks(tester, blocks, dictionaries: false);
    await _openN5(tester);

    await _add(tester);

    expect(find.text('사전을 열지 못해 단어장을 넣지 못했어요'), findsOneWidget);
    expect(await blocks.library.playlists(), isEmpty);
  });

  testWidgets('B7 빈 홈: 기본 단어장 둘러보기 opens the decks', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(app(TestBlocks(), extra: _decks()));
    await tester.pumpAndSettle();

    final button = find.text('기본 단어장 둘러보기');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '기본 단어장'), findsOneWidget);
  });

  testWidgets('B7 the guide\'s last page: 기본 단어장으로 시작 opens the decks '
      'over home', (tester) async {
    usePhoneSize(tester);
    final store = InMemoryOnboardingStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...TestBlocks().overrides,
          ...designBlocks(),
          ..._decks(),
          onboardingStoreProvider.overrideWithValue(store),
        ],
        child: const ShioriApp(firstLaunch: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기본 단어장으로 시작'), findsNothing);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('기본 단어장으로 시작'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '기본 단어장'), findsOneWidget);
    expect(await store.hasSeen(), isTrue);
    // The app speaks Korean: its back button is 뒤로, not Back.
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('B7 재생목록 편집: the 기본 단어장 button opens the decks', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(TestBlocks(), const PlaylistsScreen(), extra: _decks()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('기본 단어장'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '기본 단어장'), findsOneWidget);
  });

  test(
    'B7 the shipped deck file: five decks, JLPT N5 대비 … N1, both sources',
    () {
      final set = parseBuiltinDecks(
        File('assets/decks/jlpt.json').readAsStringSync(),
      );

      expect(
        [for (final d in set.decks) d.name],
        [
          for (final level in ['N5', 'N4', 'N3', 'N2', 'N1']) 'JLPT $level 대비',
        ],
      );
      expect(set.decks.every((d) => d.words.length > 500), isTrue);
      expect(
        [for (final s in set.sources) s.author],
        ['Jonathan Waller', 'Stephen Kraus'],
      );
      expect(
        [for (final s in set.sources) s.license],
        ['CC BY', 'CC BY-SA 4.0'],
      );
    },
    // The deck file is built, not committed (like the dictionary assets).
    skip: File('assets/decks/jlpt.json').existsSync()
        ? null
        : 'no deck file in this checkout',
  );
}
