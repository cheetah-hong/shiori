/// Crash reporting block: where uncaught errors go.
///
/// The first block is a log on the device ([CrashLog], `FileCrashLog`): nothing
/// leaves the phone, and the learner can read and copy it from the 정보 screen.
/// A crash service (Sentry, Crashlytics, ...) would be another [CrashReporter]
/// passed to [installCrashHandlers] in `main.dart` (docs/architecture.md, 5).
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Which global handler caught the error.
enum CrashSource {
  /// `FlutterError.onError`: build, layout, paint, gestures.
  flutter,

  /// `PlatformDispatcher.onError`: uncaught errors outside the framework
  /// (futures nobody awaited, platform channel callbacks).
  platform,
}

/// One uncaught error, as recorded.
@immutable
final class CrashReport {
  const CrashReport({
    required this.time,
    required this.source,
    required this.error,
    this.stack,
    this.context,
  });

  final DateTime time;
  final CrashSource source;

  /// The error's own text (`toString()`).
  final String error;
  final String? stack;

  /// Where the framework says it happened ("while building Foo"), if known.
  final String? context;

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'source': source.name,
    'error': error,
    if (stack != null) 'stack': stack,
    if (context != null) 'context': context,
  };

  /// Null for anything that is not a record written by [toJson], whatever
  /// its shape (a damaged line must not hide the other records).
  static CrashReport? tryFromJson(Object? json) {
    if (json case {
      'time': final String time,
      'source': final String source,
      'error': final String error,
    }) {
      final parsedTime = DateTime.tryParse(time);
      final parsedSource = CrashSource.values.asNameMap()[source];
      if (parsedTime == null || parsedSource == null) return null;
      final stack = json['stack'];
      final context = json['context'];
      return CrashReport(
        time: parsedTime,
        source: parsedSource,
        error: error,
        stack: stack is String ? stack : null,
        context: context is String ? context : null,
      );
    }
    return null;
  }

  /// Plain text for the screen and the clipboard.
  String format() {
    final buffer = StringBuffer()
      ..writeln('[${time.toIso8601String()}] ${source.name}')
      ..writeln(error);
    if (context != null) buffer.writeln(context);
    if (stack != null && stack!.isNotEmpty) buffer.writeln(stack!.trimRight());
    return buffer.toString().trimRight();
  }
}

/// Port: receives every uncaught error. [record] must never throw; a reporter
/// that cannot store or send a report drops it.
abstract interface class CrashReporter {
  Future<void> record(CrashReport report);
}

/// A reporter whose records stay on the device and can be read back.
abstract interface class CrashLog implements CrashReporter {
  /// Records, oldest first.
  Future<List<CrashReport>> read();

  Future<void> clear();
}

/// Routes the framework's and the platform's uncaught errors to [reporter].
///
/// The usual handling stays: [present] (`FlutterError.presentError`, the
/// console dump, when null) still runs for framework errors, and platform
/// errors are left unhandled (`false`) so the engine still prints them.
/// Recording runs in the background and never throws into the handler.
void installCrashHandlers(
  CrashReporter reporter, {
  PlatformDispatcher? dispatcher,
  DateTime Function() now = DateTime.now,
  FlutterExceptionHandler? present,
}) {
  final platform = dispatcher ?? PlatformDispatcher.instance;

  void keep(
    CrashSource source,
    Object error,
    StackTrace? stack, {
    String? context,
  }) {
    final report = CrashReport(
      time: now(),
      source: source,
      error: '$error',
      stack: stack?.toString(),
      context: context,
    );
    // record must not throw, but a reporter that does anyway must not take
    // the error handler down with it.
    unawaited(
      Future<void>.sync(() => reporter.record(report)).catchError(
        (Object e) => debugPrint('[shiori] crash report dropped: $e'),
      ),
    );
  }

  FlutterError.onError = (details) {
    keep(
      CrashSource.flutter,
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
    (present ?? FlutterError.presentError)(details);
  };
  platform.onError = (error, stack) {
    debugPrint('[shiori] uncaught: $error\n$stack');
    keep(CrashSource.platform, error, stack);
    return false; // keep the engine's default handling as well
  };
}
