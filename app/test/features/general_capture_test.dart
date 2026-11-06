// E7 (app side) and the general sample page: every page goes through the
// word extractor. A word the learner hid is left out and counted; a word
// already in the library stays, marked as keeping its stored meaning.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/dev_samples.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

/// The core package's copy of the synthetic general pages.
const _coreCopy = '../packages/core/test/fixtures/synthetic_general';

Future<void> _openGeneralSample(WidgetTester tester) async {
  final sample = generalDevSamples.first;
  await tester.tap(find.text('페이지 등록'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(sample.detail).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(sample.detail).first);
  await tester.pumpAndSettle();
}

/// Puts [headword] into the library, in a playlist.
Future<Word> _seedWord(LibraryRepository library, String headword) async {
  final created = DateTime(2026, 11, 1);
  await library.savePlaylist(
    Playlist(id: 'pl-1', name: 'JLPT 단어장', createdAt: created, position: 0),
  );
  final word = Word(
    id: 'w-1',
    headword: headword,
    readings: const ['がっこう'],
    meaning: '학교',
    createdAt: created,
  );
  await library.insertWords([word]);
  await library.addToPlaylist('pl-1', [word.id], at: created);
  return word;
}

const _inLibraryMark = '이미 라이브러리에 있음 · 저장된 뜻 유지';

final _entryTile = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('entry-'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every general sample page is bundled and matches the core copy', () {
    expect(generalDevSamples, isNotEmpty);
    for (final sample in generalDevSamples) {
      for (final lang in ['ja', 'ko']) {
        final name = '${sample.id}.$lang.json';
        expect(
          File('$devSampleDir/$name').readAsStringSync(),
          File('$_coreCopy/$name').readAsStringSync(),
          reason: '$name: run python3 tools/synthetic/make_general_pages.py',
        );
      }
    }
  });

  test('the sample recognizer reads the general pages', () async {
    final recognizer = devSampleRecognizer(rootBundle);
    for (final sample in generalDevSamples) {
      final scan = await recognizer.recognize(sample.image);
      expect(scan.japanese.lines, isNotEmpty, reason: sample.id);
    }
  });

  testWidgets('the general sample opens the review', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    await _openGeneralSample(tester);

    expect(find.text('검토'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-heading')), findsOneWidget);
    expect(find.textContaining('범용 추출'), findsNothing);
    expect(find.textContaining('건너뜀'), findsNothing);
  });

  testWidgets('a word already in the library stays on the review, marked '
      'as keeping its stored meaning', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await _seedWord(blocks.library, '学校');
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    await _openGeneralSample(tester);

    expect(find.text('이미 있는 단어 1개는 저장된 뜻을 그대로 써요'), findsOneWidget);
    expect(find.textContaining('숨긴 단어'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(_inLibraryMark),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(_inLibraryMark), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: find.text(_inLibraryMark), matching: _entryTile),
        matching: find.text('学校'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a hidden word is left out and counted in the summary', (
    tester,
  ) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    final word = await _seedWord(blocks.library, '学校');
    await LibraryService(
      library: blocks.library,
      clock: blocks.clock,
    ).hideWords([word.id]);
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    await _openGeneralSample(tester);

    expect(find.text('숨긴 단어 1개는 뺐어요'), findsOneWidget);
    expect(find.textContaining('이미 있는 단어'), findsNothing);
    expect(find.text(_inLibraryMark), findsNothing);
    expect(find.byKey(const ValueKey('cell-0-headword')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Scrollable).first,
        matching: find.text('学校'),
      ),
      findsNothing,
    );
  });
}
