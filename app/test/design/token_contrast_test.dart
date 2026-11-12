// U3: the color tokens, light and dark. Text on the backgrounds it is laid
// on reaches 4.5:1 (WCAG AA), the edges of things you press 3:1, and the
// palette keeps to three tones (lightness steps of one tone count once;
// the functional colors ok / warn / risk are apart). Pure computation, so
// any palette put in the tokens is checked the same way.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Hue in degrees and chroma (max − min channel, 0..1).
(double, double) _hueChroma(Color c) {
  final hsv = HSVColor.fromColor(c);
  final mx = [c.r, c.g, c.b].reduce(math.max);
  final mn = [c.r, c.g, c.b].reduce(math.min);
  return (hsv.hue, mx - mn);
}

void main() {
  for (final (name, t) in [
    ('light', ShioriTokens.light),
    ('dark', ShioriTokens.dark),
  ]) {
    group(name, () {
      test('text reaches 4.5:1 on every background it sits on', () {
        final pairs = <String, (Color, Color)>{
          for (final (fn, f) in [
            ('text', t.text),
            ('text2', t.text2),
            ('text3', t.text3),
            ('accentText', t.accentText),
          ])
            for (final (bn, b) in [('bg', t.bg), ('surface', t.surface)])
              '$fn on $bn': (f, b),
          'text on surfaceStrong': (t.text, t.surfaceStrong),
          'text2 on surfaceStrong': (t.text2, t.surfaceStrong),
          'text3 on surfaceStrong': (t.text3, t.surfaceStrong),
          'text on accentTint': (t.text, t.accentTint),
          'accentText on accentTint': (t.accentText, t.accentTint),
          'onAccent on accent': (t.onAccent, t.accent),
          'ok on okBg': (t.ok, t.okBg),
          'warn on warnBg': (t.warn, t.warnBg),
          'risk on riskBg': (t.risk, t.riskBg),
          'ok on bg': (t.ok, t.bg),
          'warn on bg': (t.warn, t.bg),
          'risk on bg': (t.risk, t.bg),
          'onRisk on risk': (t.onRisk, t.risk),
          'bg on text (snack bar)': (t.bg, t.text),
        };
        for (final MapEntry(key: label, value: (fg, bg)) in pairs.entries) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$label ${contrast(fg, bg).toStringAsFixed(2)}',
          );
        }
      });

      test('edges of things you press reach 3:1', () {
        for (final (label, edge, bg) in [
          ('outline on bg', t.outline, t.bg),
          ('outline on surface', t.outline, t.surface),
          ('accent on bg', t.accent, t.bg),
          ('accent on surface', t.accent, t.surface),
        ]) {
          expect(
            contrast(edge, bg),
            greaterThanOrEqualTo(3),
            reason: '$label ${contrast(edge, bg).toStringAsFixed(2)}',
          );
        }
      });

      test('three tones at most, functional colors apart', () {
        final palette = [
          t.bg,
          t.surface,
          t.surfaceStrong,
          t.line,
          t.text,
          t.text2,
          t.text3,
          t.outline,
          t.accent,
          t.accentTint,
          t.accentText,
          t.onAccent,
        ];
        // Near-grey colors (chroma under 0.12) count as one light and one
        // dark neutral tone; colored ones by hue, 20 degrees apart at most.
        var lightNeutral = false;
        var darkNeutral = false;
        final hues = <double>[];
        for (final c in palette) {
          final (hue, chroma) = _hueChroma(c);
          if (chroma < 0.12) {
            if (_luminance(c) > 0.18) {
              lightNeutral = true;
            } else {
              darkNeutral = true;
            }
            continue;
          }
          final near = hues.any((h) {
            final d = (h - hue).abs();
            return math.min(d, 360 - d) <= 20;
          });
          if (!near) hues.add(hue);
        }
        final tones =
            hues.length + (lightNeutral ? 1 : 0) + (darkNeutral ? 1 : 0);
        expect(tones, lessThanOrEqualTo(3), reason: 'hues $hues');
      });
    });
  }

  test('the theme paints with the tokens (buttons, FAB, errors)', () {
    for (final (brightness, t) in [
      (Brightness.light, ShioriTokens.light),
      (Brightness.dark, ShioriTokens.dark),
    ]) {
      final theme = buildTheme(brightness);
      final scheme = theme.colorScheme;
      expect(scheme.primary, t.accent);
      expect(scheme.onPrimary, t.onAccent);
      expect(scheme.error, t.risk);
      expect(scheme.onError, t.onRisk);
      expect(theme.scaffoldBackgroundColor, t.bg);
      expect(theme.floatingActionButtonTheme.backgroundColor, t.accent);
      expect(theme.floatingActionButtonTheme.foregroundColor, t.onAccent);
      expect(theme.extension<ShioriTokens>(), t);
    }
  });
}
