import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/app.dart';

/// Blocks are wired in `lib/app/blocks.dart`. To swap one, add an override here:
///
/// ```dart
/// ProviderScope(overrides: [reviewSchedulerProvider.overrideWithValue(FsrsScheduler())], ...)
/// ```
void main() {
  // TODO(crash-reporting): forward these to a crash reporter block.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[shiori] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[shiori] uncaught: $error\n$stack');
    return false; // keep the engine's default handling as well
  };
  runApp(const ProviderScope(child: ShioriApp()));
}
