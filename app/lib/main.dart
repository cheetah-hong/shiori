import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/file_crash_log.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/crash_reporting.dart';
import 'package:shiori/app/startup.dart';
import 'package:shiori/features/about/about_screen.dart';

/// Blocks are wired in `lib/app/blocks.dart`. To swap one, add an override here:
///
/// ```dart
/// ProviderScope(overrides: [reviewSchedulerProvider.overrideWithValue(FsrsScheduler())], ...)
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uncaught errors go to a log on the device (정보 → 오류 기록). A crash
  // service would be another reporter here (docs/architecture.md, 5).
  final crashLog = FileCrashLog.appSupport();
  installCrashHandlers(crashLog);
  registerDictionaryLicense();
  registerGlossaryLicense();
  registerExtractorLicenses();
  // Unpacking the dictionaries starts now and runs while the app starts.
  final dictionary = bundledDictionaryOverride();
  final glossary = bundledGlossaryOverride();
  final database = await appDatabaseOverride();
  runApp(
    ProviderScope(
      overrides: [
        database,
        dictionary,
        glossary,
        crashLogProvider.overrideWithValue(crashLog),
      ],
      child: const ShioriApp(),
    ),
  );
}
