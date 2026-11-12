// 정보 → 개인정보: what the app keeps and where, with the full privacy policy
// inside the app (it opens no browser). The web address and the contact line
// appear only once they are filled in.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/about/about_screen.dart';
import 'package:shiori/features/about/privacy_policy.dart';

import '../support/harness.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  usePhoneSize(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: TestBlocks().overrides,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _section({String? url, String? contact}) => Scaffold(
  body: ListView(
    children: [PrivacySection(url: url, contact: contact)],
  ),
);

/// Every text on screen, offstage too.
Iterable<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

void main() {
  testWidgets('the 정보 screen has the 개인정보 section', (tester) async {
    await _pump(tester, const AboutScreen());
    await tester.scrollUntilVisible(find.text('개인정보처리방침'), 300);

    expect(find.text('개인정보'), findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);
  });

  testWidgets('says nothing is collected; no web link until there is one', (
    tester,
  ) async {
    await _pump(tester, _section());

    expect(find.textContaining('수집하지 않'), findsWidgets);
    expect(find.textContaining('https://'), findsNothing);
  });

  testWidgets('shows the web address once it is set', (tester) async {
    await _pump(tester, _section(url: 'https://example.org/shiori/privacy'));

    expect(find.text('https://example.org/shiori/privacy'), findsOneWidget);
  });

  testWidgets('opens the full policy', (tester) async {
    await _pump(tester, _section());
    await tester.tap(find.text('개인정보처리방침'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    for (final heading in [
      '수집하는 정보',
      '기기 안에 저장되는 정보',
      '사진과 카메라',
      '기기 백업',
      '제3자 제공',
    ]) {
      expect(
        find.text(heading, skipOffstage: false),
        findsOneWidget,
        reason: heading,
      );
    }
  });

  testWidgets('no placeholder and no contact line without a contact', (
    tester,
  ) async {
    await _pump(tester, const PrivacyPolicyScreen(contact: null));

    final texts = _texts(tester).join('\n');
    expect(texts, isNot(contains('<')));
    expect(texts, isNot(contains('>')));
    expect(texts, isNot(contains('문의')));
  });

  test('the web page (site/privacy.html) says what the app says', () {
    final page = File('../site/privacy.html')
        .readAsStringSync()
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ');
    String flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

    expect(privacyPolicySections, isNotEmpty);
    for (final section in privacyPolicySections) {
      expect(page, contains(flat(section.heading)));
      for (final paragraph in section.paragraphs) {
        expect(page, contains(flat(paragraph)), reason: section.heading);
      }
    }
    expect(page, contains(flat(privacyPolicyEffective)));
  });

  testWidgets('the contact line appears once a contact is set', (tester) async {
    await _pump(tester, const PrivacyPolicyScreen(contact: 'help@example.org'));

    expect(
      _texts(tester).where((t) => t.contains('help@example.org')),
      hasLength(1),
    );
  });
}
