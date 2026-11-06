// E7 (app side) and the general sample page: every page goes through the
// word extractor, and words already in the library (every word the
// repository lists) are skipped and counted.
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

Future<void> _seedWord(LibraryRepository library, String headword) async {
  final created = DateTime(2026, 11, 1);
  await library.saveTextbook(
    Textbook(id: 'tb-1', title: 'JLPT 단어장', createdAt: created),
  );
  await library.saveWords([
    Word(
      id: 'tb-1:0001',
      textbookId: 'tb-1',
      headword: headword,
      readings: const ['がっこう'],
      meaning: '학교',
      createdAt: created,
    ),
  ]);
}

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

  testWidgets('a word already saved (hidden ones too: every listed word) is '
      'skipped and counted in the summary', (tester) async {
    usePhoneSize(tester);
    final blocks = TestBlocks();
    await _seedWord(blocks.library, '学校');
    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    await _openGeneralSample(tester);

    expect(find.text('이미 있는 단어 1개 건너뜀'), findsOneWidget);
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
