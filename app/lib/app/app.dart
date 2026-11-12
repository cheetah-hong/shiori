import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/home/home_screen.dart';
import 'package:shiori/features/onboarding/onboarding_gate.dart';
import 'package:shiori/features/opening/opening.dart';

class ShioriApp extends StatelessWidget {
  const ShioriApp({super.key, this.firstLaunch = false});

  /// The app as started on the device: the first-run guide comes first when
  /// it has not been seen, under the cold-start opening. Tests and previews
  /// leave it off and open on 홈.
  final bool firstLaunch;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '시오리',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      builder: Motion.follow,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('ja', 'JP')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: firstLaunch
          ? const Opening(child: OnboardingGate(child: HomeScreen()))
          : const HomeScreen(),
    );
  }
}
