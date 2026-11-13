import 'package:flutter/material.dart';
import 'package:shiori/app/fonts.dart';

/// Color tokens by role. Every widget reads colors from here; the values
/// live only in [light] and [dark], so the palette changes in one place.
///
/// Three tones and their lightness steps: background (bg, surface,
/// surfaceStrong, line), text (text, text2, text3, outline) and accent
/// (accent, accentTint, accentText, onAccent). The functional colors
/// (ok, warn, risk) mark states the learner must tell apart. Text pairs
/// meet 4.5:1 and outlines of things you can press 3:1 against bg and
/// surface (test/design/token_contrast_test.dart).
@immutable
final class ShioriTokens extends ThemeExtension<ShioriTokens> {
  const ShioriTokens({
    required this.bg,
    required this.surface,
    required this.surfaceStrong,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.outline,
    required this.accent,
    required this.accentTint,
    required this.accentText,
    required this.onAccent,
    required this.ok,
    required this.okBg,
    required this.warn,
    required this.warnBg,
    required this.risk,
    required this.riskBg,
    required this.onRisk,
    required this.shadow,
  });

  static const light = ShioriTokens(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F8F2),
    surfaceStrong: Color(0xFFE9EFE4),
    line: Color(0xFFDFE6D8),
    text: Color(0xFF1F2A22),
    text2: Color(0xFF4B5A4E),
    text3: Color(0xFF5F6E62),
    outline: Color(0xFF76857A),
    accent: Color(0xFF287A4E),
    accentTint: Color(0xFFE3F2E8),
    accentText: Color(0xFF247349),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF287A4E),
    okBg: Color(0xFFE3F2E8),
    warn: Color(0xFF8F5300),
    warnBg: Color(0xFFFCF0D9),
    risk: Color(0xFFB02525),
    riskBg: Color(0xFFFDE8E8),
    onRisk: Color(0xFFFFFFFF),
    shadow: Color(0x1A000000),
  );

  static const dark = ShioriTokens(
    bg: Color(0xFF111612),
    surface: Color(0xFF1B231D),
    surfaceStrong: Color(0xFF243028),
    line: Color(0xFF2A352D),
    text: Color(0xFFE7EFE8),
    text2: Color(0xFFB7C4B9),
    text3: Color(0xFF9AAA9D),
    outline: Color(0xFF778879),
    accent: Color(0xFF6CC593),
    accentTint: Color(0xFF1C3526),
    accentText: Color(0xFF6CC593),
    onAccent: Color(0xFF0B1F12),
    ok: Color(0xFF6CC593),
    okBg: Color(0xFF1C3526),
    warn: Color(0xFFF2BC62),
    warnBg: Color(0xFF3A2B0E),
    risk: Color(0xFFFF8078),
    riskBg: Color(0xFF3E1719),
    onRisk: Color(0xFF2A0A0A),
    shadow: Color(0x66000000),
  );

  /// Page background.
  final Color bg;

  /// Cards, sheets and fields laid on the page.
  final Color surface;

  /// Pressed and selected fills, tracks, disabled fills.
  final Color surfaceStrong;

  /// Decorative dividers and card edges (not for things you press).
  final Color line;

  /// Body text, headings.
  final Color text;

  /// Secondary text.
  final Color text2;

  /// The faintest text (captions, hints). Still 4.5:1 on bg and surface.
  final Color text3;

  /// Edges of things you press: fields, checkboxes, answer options (3:1).
  final Color outline;

  /// The one accent: primary buttons, the selected thing, the pitch line.
  final Color accent;

  /// Accent wash: highlight behind a word, selected chip, badge fill.
  final Color accentTint;

  /// Accent-colored text on bg, surface and accentTint.
  final Color accentText;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Right, auto-corrected, high confidence.
  final Color ok;
  final Color okBg;

  /// Things to look at: medium (or lower) confidence, cells the learner
  /// should check (확인 필요), development-only things.
  final Color warn;
  final Color warnBg;

  /// Only what is wrong or cannot be undone: a wrong answer, destructive
  /// actions such as delete, errors.
  final Color risk;
  final Color riskBg;

  /// Text on [risk].
  final Color onRisk;

  /// Material's elevation shadow. The app draws none of its own: depth is
  /// paper and rules, not shadows.
  final Color shadow;

  @override
  ShioriTokens copyWith({
    Color? bg,
    Color? surface,
    Color? text,
    Color? accent,
  }) => ShioriTokens(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceStrong: surfaceStrong,
    line: line,
    text: text ?? this.text,
    text2: text2,
    text3: text3,
    outline: outline,
    accent: accent ?? this.accent,
    accentTint: accentTint,
    accentText: accentText,
    onAccent: onAccent,
    ok: ok,
    okBg: okBg,
    warn: warn,
    warnBg: warnBg,
    risk: risk,
    riskBg: riskBg,
    onRisk: onRisk,
    shadow: shadow,
  );

  @override
  ShioriTokens lerp(ShioriTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return ShioriTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceStrong: l(surfaceStrong, other.surfaceStrong),
      line: l(line, other.line),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      outline: l(outline, other.outline),
      accent: l(accent, other.accent),
      accentTint: l(accentTint, other.accentTint),
      accentText: l(accentText, other.accentText),
      onAccent: l(onAccent, other.onAccent),
      ok: l(ok, other.ok),
      okBg: l(okBg, other.okBg),
      warn: l(warn, other.warn),
      warnBg: l(warnBg, other.warnBg),
      risk: l(risk, other.risk),
      riskBg: l(riskBg, other.riskBg),
      onRisk: l(onRisk, other.onRisk),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// Spacing and shape scale. Rhythm is deliberate: tight inside cards, loose between sections.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double section = 32;
  static const double gutter = 16;
}

abstract final class Radii {
  static const double chip = 999;

  /// Every button, filled or washed: one shape.
  static const double button = 14;
  static const double tile = 16;
  static const double card = 24;
  static const double wordCard = 28;
}

abstract final class Motion {
  static const Duration press = Duration(milliseconds: 140);
  static const Duration ui = Duration(milliseconds: 240);
  static const Duration card = Duration(milliseconds: 360);
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);
  static const Curve easeExpo = Cubic(0.16, 1, 0.3, 1);

  /// Zero when the system asks for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// Whether the system asks for reduced motion (see [follow]).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// `MaterialApp.builder`: iOS 「동작 줄이기」 sets only the platform's
  /// `reduceMotion` flag, not `disableAnimations`; this carries it into the
  /// app's MediaQuery so [of], [reduced] and the framework's own transitions
  /// all see it, also when it is switched while the app runs.
  static Widget follow(BuildContext context, Widget? child) =>
      _ReduceMotion(child: child ?? const SizedBox.shrink());
}

/// Rebuilds when the system's accessibility features change (the
/// MediaQuery does not carry `reduceMotion`, so it alone would not).
class _ReduceMotion extends StatefulWidget {
  const _ReduceMotion({required this.child});

  final Widget child;

  @override
  State<_ReduceMotion> createState() => _ReduceMotionState();
}

class _ReduceMotionState extends State<_ReduceMotion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduce = View.of(
      context,
    ).platformDispatcher.accessibilityFeatures.reduceMotion;
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduce,
      ),
      child: widget.child,
    );
  }
}

/// The type scale: every size a screen uses. Seven steps, from small print
/// to the day numeral; headwords size themselves ([JpType.headword]).
abstract final class TypeScale {
  static const double caption = 12;
  static const double small = 13;
  static const double body2 = 15;
  static const double body = 17;
  static const double title = 20;
  static const double display = 28;
  static const double page = 96;
}

/// Three weights only: text, emphasis (labels, buttons, titles) and the
/// display marks (the day numeral, headwords, a screen's one big title).
abstract final class Weights {
  static const FontWeight text = FontWeight.w400;
  static const FontWeight emphasis = FontWeight.w600;
  static const FontWeight display = FontWeight.w700;
}

/// Japanese type: the app's one typeface ([AppFonts]), marked Japanese so
/// kanji take their Japanese forms on a Korean phone and VoiceOver reads
/// them in Japanese.
abstract final class JpType {
  static const Locale locale = Locale('ja', 'JP');

  /// A headword or a word shown large.
  static TextStyle headword(
    double size,
    Color color, {
    FontWeight weight = Weights.display,
  }) => TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    height: 1.2,
    color: color,
    locale: locale,
  );

  /// Readings, examples and other running Japanese text.
  static TextStyle body(
    double size,
    Color color, {
    FontWeight weight = Weights.text,
    double height = 1.6,
  }) => TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    locale: locale,
  );
}

/// The one button shape (DESIGN.md B): a square with 14 pt corners.
final buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(Radii.button),
);

ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.light
      ? ShioriTokens.light
      : ShioriTokens.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.accent,
    onPrimary: t.onAccent,
    primaryContainer: t.accentTint,
    onPrimaryContainer: t.accentText,
    secondary: t.accent,
    onSecondary: t.onAccent,
    secondaryContainer: t.accentTint,
    onSecondaryContainer: t.accentText,
    tertiary: t.accent,
    onTertiary: t.onAccent,
    error: t.risk,
    onError: t.onRisk,
    errorContainer: t.riskBg,
    onErrorContainer: t.risk,
    surface: t.bg,
    onSurface: t.text,
    surfaceContainerLowest: t.bg,
    surfaceContainerLow: t.surface,
    surfaceContainer: t.surface,
    surfaceContainerHigh: t.surfaceStrong,
    surfaceContainerHighest: t.surfaceStrong,
    onSurfaceVariant: t.text3,
    outline: t.outline,
    outlineVariant: t.line,
    shadow: t.shadow,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    // Presses on iOS do not splash; buttons and rows answer with a press
    // scale or a light highlight instead.
    splashFactory: NoSplash.splashFactory,
  );
  final text = base.textTheme.apply(
    bodyColor: t.text,
    displayColor: t.text,
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
  );

  return base.copyWith(
    scaffoldBackgroundColor: t.bg,
    extensions: [t],
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        fontSize: TypeScale.display,
        fontWeight: Weights.display,
        letterSpacing: -0.6,
        height: 1.2,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: Weights.emphasis,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: TypeScale.title,
        fontWeight: Weights.emphasis,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: TypeScale.body,
        fontWeight: Weights.emphasis,
      ),
      titleSmall: text.titleSmall?.copyWith(
        fontSize: TypeScale.body2,
        fontWeight: Weights.emphasis,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: TypeScale.body),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: TypeScale.body2),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: TypeScale.body2,
        fontWeight: Weights.emphasis,
      ),
      labelMedium: text.labelMedium?.copyWith(
        fontSize: TypeScale.small,
        fontWeight: Weights.emphasis,
      ),
      labelSmall: text.labelSmall?.copyWith(
        fontSize: TypeScale.caption,
        fontWeight: Weights.emphasis,
      ),
      bodySmall: text.bodySmall?.copyWith(
        fontSize: TypeScale.small,
        color: t.text3,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // An iOS inline navigation bar, as 홈's: the title in the middle,
      // its buttons in the accent.
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        color: t.text,
        fontSize: TypeScale.body,
        fontWeight: Weights.emphasis,
      ),
      iconTheme: IconThemeData(color: t.accentText),
      actionsIconTheme: IconThemeData(color: t.accentText),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        disabledBackgroundColor: t.surfaceStrong,
        disabledForegroundColor: t.text3,
        minimumSize: const Size(48, 52),
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: AppFonts.family,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: Weights.emphasis,
          fontSize: TypeScale.body2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      // The secondary button: an accent wash with accent words, no edge.
      style: OutlinedButton.styleFrom(
        foregroundColor: t.accentText,
        backgroundColor: t.accentTint,
        disabledForegroundColor: t.text3,
        disabledBackgroundColor: t.surface,
        side: BorderSide.none,
        minimumSize: const Size(48, 48),
        shape: buttonShape,
        textStyle: const TextStyle(
          fontFamily: AppFonts.family,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: Weights.emphasis,
          fontSize: TypeScale.body2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.accentText,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: AppFonts.family,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: Weights.emphasis,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.accent,
      foregroundColor: t.onAccent,
      extendedTextStyle: const TextStyle(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        fontWeight: Weights.emphasis,
        fontSize: TypeScale.body2,
      ),
      shape: buttonShape,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.bg,
      selectedColor: t.accentTint,
      disabledColor: t.surface,
      side: BorderSide(color: t.outline),
      labelStyle: TextStyle(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        color: t.text,
        fontWeight: Weights.emphasis,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        color: t.accentText,
        fontWeight: Weights.emphasis,
      ),
      checkmarkColor: t.accentText,
      shape: buttonShape,
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: t.outline, width: 2),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? t.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(t.onAccent),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.onAccent : t.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.accent : t.surfaceStrong,
      ),
      trackOutlineColor: WidgetStatePropertyAll(t.outline),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.accent : t.outline,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
        borderSide: BorderSide(color: t.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
        borderSide: BorderSide(color: t.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
        borderSide: BorderSide(color: t.accent, width: 2),
      ),
      labelStyle: TextStyle(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        color: t.text3,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.text,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        color: t.bg,
        fontWeight: Weights.emphasis,
      ),
      actionTextColor: t.accentTint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      showDragHandle: true,
      dragHandleColor: t.outline,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.accent,
      linearTrackColor: t.surfaceStrong,
    ),
    focusColor: t.accentTint,
  );
}

extension ShioriThemeContext on BuildContext {
  ShioriTokens get tokens =>
      Theme.of(this).extension<ShioriTokens>() ?? ShioriTokens.light;
  TextTheme get text => Theme.of(this).textTheme;
}
