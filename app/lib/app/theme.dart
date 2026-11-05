import 'package:flutter/material.dart';

/// Design tokens from the plan page (artifact DpCWSY6EuuMuSgbweoTF2a):
/// paper background, navy ink, highlighter marker, red pen.
/// Every widget reads colors and type from here.
@immutable
final class ShioriTokens extends ThemeExtension<ShioriTokens> {
  const ShioriTokens({
    required this.paper,
    required this.paper2,
    required this.paper3,
    required this.sheet,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.marker,
    required this.markerInk,
    required this.pen,
    required this.ok,
    required this.okBg,
    required this.warn,
    required this.warnBg,
    required this.risk,
    required this.riskBg,
  });

  static const light = ShioriTokens(
    paper: Color(0xFFEDEFE8),
    paper2: Color(0xFFE1E4DA),
    paper3: Color(0xFFD2D6CA),
    sheet: Color(0xFFFAFBF6),
    ink: Color(0xFF161D36),
    ink2: Color(0xFF3A425E),
    ink3: Color(0xFF4F5774),
    marker: Color(0xFFE3F25A),
    markerInk: Color(0xFF161D36),
    pen: Color(0xFFB81E25),
    ok: Color(0xFF1B6A43),
    okBg: Color(0xFFD5E9DC),
    warn: Color(0xFF855000),
    warnBg: Color(0xFFF2E1BD),
    risk: Color(0xFFAF2128),
    riskBg: Color(0xFFF4D8D7),
  );

  static const dark = ShioriTokens(
    paper: Color(0xFF0E1226),
    paper2: Color(0xFF161B34),
    paper3: Color(0xFF232944),
    sheet: Color(0xFF1A2040),
    ink: Color(0xFFE8EBF5),
    ink2: Color(0xFFB3B9D0),
    ink3: Color(0xFF9AA1BC),
    marker: Color(0xFFD4E34C),
    markerInk: Color(0xFF10142A),
    pen: Color(0xFFFF6E63),
    ok: Color(0xFF79D9A5),
    okBg: Color(0xFF123726),
    warn: Color(0xFFF2BC62),
    warnBg: Color(0xFF3A2B0E),
    risk: Color(0xFFFF8078),
    riskBg: Color(0xFF3E1719),
  );

  /// Page background.
  final Color paper;
  final Color paper2;
  final Color paper3;

  /// Cards and sheets laid on the paper.
  final Color sheet;

  /// Text and primary actions.
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// Highlighter: the thing to look at (new word, start button, the word in an example).
  final Color marker;
  final Color markerInk;

  /// Red pen: capture action, streaks.
  final Color pen;

  /// Auto-corrected cells.
  final Color ok;
  final Color okBg;

  /// Development-only things.
  final Color warn;
  final Color warnBg;

  /// Cells the learner must check.
  final Color risk;
  final Color riskBg;

  @override
  ShioriTokens copyWith({
    Color? paper,
    Color? sheet,
    Color? ink,
    Color? marker,
    Color? pen,
  }) => ShioriTokens(
    paper: paper ?? this.paper,
    paper2: paper2,
    paper3: paper3,
    sheet: sheet ?? this.sheet,
    ink: ink ?? this.ink,
    ink2: ink2,
    ink3: ink3,
    marker: marker ?? this.marker,
    markerInk: markerInk,
    pen: pen ?? this.pen,
    ok: ok,
    okBg: okBg,
    warn: warn,
    warnBg: warnBg,
    risk: risk,
    riskBg: riskBg,
  );

  @override
  ShioriTokens lerp(ShioriTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return ShioriTokens(
      paper: l(paper, other.paper),
      paper2: l(paper2, other.paper2),
      paper3: l(paper3, other.paper3),
      sheet: l(sheet, other.sheet),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      ink3: l(ink3, other.ink3),
      marker: l(marker, other.marker),
      markerInk: l(markerInk, other.markerInk),
      pen: l(pen, other.pen),
      ok: l(ok, other.ok),
      okBg: l(okBg, other.okBg),
      warn: l(warn, other.warn),
      warnBg: l(warnBg, other.warnBg),
      risk: l(risk, other.risk),
      riskBg: l(riskBg, other.riskBg),
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
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// Japanese type. Printed headwords use a Mincho face like the textbook;
/// readings and examples a gothic face. Both carry the `ja` locale so kanji
/// get Japanese glyph forms on a Korean phone.
abstract final class JpType {
  static const Locale locale = Locale('ja', 'JP');
  static const String _mincho = 'Hiragino Mincho ProN';
  static const List<String> _minchoFallback = [
    'Noto Serif CJK JP',
    'Noto Serif JP',
    'serif',
  ];
  static const String _gothic = 'Hiragino Sans';
  static const List<String> _gothicFallback = [
    'Noto Sans CJK JP',
    'Noto Sans JP',
    'sans-serif',
  ];

  static TextStyle print(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontFamily: _mincho,
    fontFamilyFallback: _minchoFallback,
    fontSize: size,
    fontWeight: weight,
    height: 1.15,
    color: color,
    locale: locale,
  );

  static TextStyle gothic(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w500,
    double height = 1.6,
  }) => TextStyle(
    fontFamily: _gothic,
    fontFamilyFallback: _gothicFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
    locale: locale,
  );
}

ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.light
      ? ShioriTokens.light
      : ShioriTokens.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.ink,
    onPrimary: t.sheet,
    secondary: t.marker,
    onSecondary: t.markerInk,
    tertiary: t.pen,
    onTertiary: Colors.white,
    error: t.risk,
    onError: Colors.white,
    surface: t.paper,
    onSurface: t.ink,
    surfaceContainerLowest: t.sheet,
    surfaceContainerLow: t.sheet,
    surfaceContainer: t.paper2,
    surfaceContainerHigh: t.paper2,
    surfaceContainerHighest: t.paper3,
    onSurfaceVariant: t.ink3,
    outline: t.paper3,
    outlineVariant: t.paper2,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  final text = base.textTheme.apply(bodyColor: t.ink, displayColor: t.ink);

  return base.copyWith(
    scaffoldBackgroundColor: t.paper,
    extensions: [t],
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      bodySmall: text.bodySmall?.copyWith(color: t.ink3),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.paper,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.sheet,
        disabledBackgroundColor: t.paper3,
        disabledForegroundColor: t.ink3,
        minimumSize: const Size(48, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.pen,
      foregroundColor: Colors.white,
      extendedTextStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.sheet,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
        borderSide: BorderSide(color: t.paper3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
        borderSide: BorderSide(color: t.paper3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
        borderSide: BorderSide(color: t.ink, width: 2),
      ),
      labelStyle: TextStyle(color: t.ink3),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(color: t.sheet, fontWeight: FontWeight.w600),
      actionTextColor: t.marker,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.paper,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      showDragHandle: true,
      dragHandleColor: t.paper3,
    ),
    dividerTheme: DividerThemeData(color: t.paper2, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.ink,
      linearTrackColor: t.paper2,
    ),
    focusColor: t.marker.withValues(alpha: 0.5),
  );
}

extension ShioriThemeContext on BuildContext {
  ShioriTokens get tokens =>
      Theme.of(this).extension<ShioriTokens>() ?? ShioriTokens.light;
  TextTheme get text => Theme.of(this).textTheme;
}
