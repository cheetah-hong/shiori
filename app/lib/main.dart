import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/startup.dart';

/// Blocks are wired in `lib/app/blocks.dart`. To swap one, add an override here:
///
/// ```dart
/// ProviderScope(overrides: [reviewSchedulerProvider.overrideWithValue(FsrsScheduler())], ...)
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(crash-reporting): forward these to a crash reporter block.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[shiori] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[shiori] uncaught: $error\n$stack');
    return false; // keep the engine's default handling as well
  };
  final database = await appDatabaseOverride();
  runApp(ProviderScope(overrides: [database], child: const ShioriApp()));
}
