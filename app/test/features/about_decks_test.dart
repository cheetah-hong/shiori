// B6: 정보 credits the built-in decks in a card of their own (each source,
// its licence and link, the list's edition, that it is not the test
// organizers' list), and the licence page lists both sources.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori/features/decks/decks_card.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

final _set = parseBuiltinDecks(
  jsonEncode({
    'format': 'shiori-decks',
    'version': 1,
    'edition': '2026-11-13',
    'sources': [
      {
        'name': 'JLPT Resources',
        'author': 'Jonathan Waller',
        'license': 'CC BY',
        'licenseUrl': 'https://www.tanos.co.uk/jlpt/sharing/',
        'url': 'https://www.tanos.co.uk/jlpt/',
      },
      {
        'name': 'yomitan-jlpt-vocab',
        'author': 'Stephen Kraus',
        'license': 'CC BY-SA 4.0',
        'licenseUrl': 'https://creativecommons.org/licenses/by-sa/4.0/',
        'url': 'https://github.com/stephenmk/yomitan-jlpt-vocab',
      },
    ],
    'decks': [
      {
        'id': 'jlpt-n5',
        'name': 'JLPT N5 대비',
        'level': 'N5',
        'words': [
          {'h': '雨傘', 'r': 'あまがさ', 'e': 9000001},
        ],
      },
    ],
  }),
);

void main() {
  testWidgets('B6 정보: 기본 단어장 with each source, licence, link and the '
      'list edition', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      screen(
        TestBlocks(),
        const AboutScreen(),
        extra: [builtinDecksProvider.overrideWith((ref) async => _set)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Jonathan Waller'),
      200,
    );
    expect(find.textContaining('Jonathan Waller'), findsWidgets);
    expect(find.textContaining('주최 측이 낸 목록이 아니에요'), findsOneWidget);
    for (final url in [
      'https://www.tanos.co.uk/jlpt/',
      'https://www.tanos.co.uk/jlpt/sharing/',
      'https://github.com/stephenmk/yomitan-jlpt-vocab',
      'https://creativecommons.org/licenses/by-sa/4.0/',
    ]) {
      await tester.scrollUntilVisible(find.text(url), 200);
      expect(find.text(url), findsOneWidget, reason: url);
    }
    expect(find.textContaining('Stephen Kraus'), findsWidgets);
    expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
    await tester.scrollUntilVisible(find.text('2026-11-13'), 200);
    expect(find.text('2026-11-13'), findsOneWidget);
    for (final e in find.byType(Text).evaluate()) {
      expect((e.widget as Text).data ?? '', isNot(contains('공식')));
    }
  });

  test('B6 the licence page lists both sources of the decks', () async {
    registerDeckLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = {for (final e in entries) ...e.packages};
    expect(packages, contains('JLPT Resources (Jonathan Waller)'));
    expect(packages, contains('yomitan-jlpt-vocab (Stephen Kraus)'));
    final text = [
      for (final e in entries)
        for (final p in e.paragraphs) p.text,
    ].join('\n');
    expect(text, contains('https://www.tanos.co.uk/jlpt/sharing/'));
    expect(text, contains('CC BY-SA 4.0'));
    expect(text, isNot(contains('공식')));
  });
}
