// F4: one typeface for Korean and Japanese — Pretendard JP, bundled in three
// static weights (400, 600, 700) — with Japanese text marked as Japanese,
// no Mincho anywhere, and the font's licence on the licences page.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/fonts.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/widgets.dart';

import '../support/screen_fit.dart';

const _family = 'PretendardJP';
const _weights = {
  400: 'assets/fonts/PretendardJP-Regular.otf',
  600: 'assets/fonts/PretendardJP-SemiBold.otf',
  700: 'assets/fonts/PretendardJP-Bold.otf',
};

void main() {
  test('the three weights are bundled and declared', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: $_family'));
    for (final MapEntry(key: weight, value: path) in _weights.entries) {
      expect(File(path).lengthSync(), greaterThan(1000000), reason: path);
      expect(
        RegExp(
          '- asset: ${RegExp.escape(path)}\\s+weight: $weight',
        ).hasMatch(pubspec),
        isTrue,
        reason: '$path at $weight',
      );
    }
    expect(File('assets/fonts/OFL.txt').readAsStringSync(), contains('SIL'));
  });

  test('the theme sets the family, Japanese falls back to a gothic', () {
    expect(AppFonts.family, _family);
    expect(AppFonts.fallback, ['Hiragino Sans']);
    for (final b in Brightness.values) {
      final theme = buildTheme(b);
      for (final style in [
        theme.textTheme.bodyMedium,
        theme.textTheme.titleLarge,
        theme.textTheme.labelLarge,
      ]) {
        expect(style?.fontFamily, _family);
        expect(style?.fontFamilyFallback, AppFonts.fallback);
      }
    }
  });

  test('Japanese text: the same family, marked Japanese', () {
    for (final style in [
      JpType.headword(48, Colors.black),
      JpType.body(17, Colors.black),
    ]) {
      expect(style.fontFamily, _family);
      expect(style.fontFamilyFallback, AppFonts.fallback);
      expect(style.locale, const Locale('ja', 'JP'));
    }
  });

  test('no Mincho or serif anywhere', () {
    final hits = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final (i, line) in file.readAsLinesSync().indexed) {
        if (RegExp(r'Mincho|Serif|serif').hasMatch(line)) {
          hits.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty);
  });

  testWidgets('the headword on a card is Pretendard JP, in Japanese', (
    tester,
  ) async {
    useFit(tester, const Size(390, 844), 1);
    await openFitScreen(tester, designScreen('study meaning'));
    final head = find.descendant(
      of: find.byKey(const ValueKey('card-headword')),
      matching: find.byType(RichText),
    );
    final paragraph = tester.widget<RichText>(head);
    final span = paragraph.text as TextSpan;
    expect(paragraph.text.style?.fontFamily, _family);
    final locales = <Locale?>[span.locale];
    span.visitChildren((child) {
      if (child is TextSpan) locales.add(child.locale);
      return true;
    });
    expect(locales, contains(const Locale('ja', 'JP')));
    expect(find.byType(JpText), findsWidgets);
  });

  test('its licence is on the licences page', () async {
    registerFontLicense();
    registerFontLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final font = entries.where((e) => e.packages.contains('Pretendard JP'));
    expect(font, hasLength(1));
    final text = font.single.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL Open Font License'));
    expect(text, contains('Pretendard'));
  });

  test('the licence is registered when the app starts', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('registerFontLicense()'));
  });
}
