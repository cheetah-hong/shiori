import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/app/crash_reporting.dart';

/// Crash log in a text file in the app support folder: one JSON record per
/// line, oldest first, at most [maxBytes]. Nothing is sent anywhere.
///
/// Operations run one at a time, and each write replaces the whole file
/// (a temporary file renamed over it), so a crash mid-write leaves the old log.
final class FileCrashLog implements CrashLog {
  FileCrashLog({required this.directory, this.maxBytes = defaultMaxBytes});

  /// The log in the app support folder (not shared with other apps).
  factory FileCrashLog.appSupport() =>
      FileCrashLog(directory: getApplicationSupportDirectory);

  static const String fileName = 'crash_log.jsonl';
  static const int defaultMaxBytes = 64 * 1024;

  /// Longest error text and stack kept per record.
  static const int maxErrorChars = 4000;
  static const int maxStackLines = 60;

  /// Where the file lives; asked on every use.
  final Future<Directory> Function() directory;

  /// Upper bound of the file size; the oldest records go first.
  final int maxBytes;

  /// The same error again within this time is not written again, so an error
  /// repeated every frame neither floods the disk nor pushes out the first,
  /// usually the telling, record.
  static const Duration repeatWindow = Duration(minutes: 1);

  Future<void> _last = Future<void>.value();
  ({String key, DateTime time})? _lastRecorded;

  /// Runs [operation] after the ones before it; its error goes to the caller only.
  Future<T> _inTurn<T>(Future<T> Function() operation) {
    final result = _last.then((_) => operation());
    _last = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<File> _file() async =>
      File('${(await directory()).path}${Platform.pathSeparator}$fileName');

  @override
  Future<void> record(CrashReport report) {
    final key = '${report.source.name}\n${report.error}\n${report.context}';
    final last = _lastRecorded;
    if (last != null &&
        last.key == key &&
        report.time.difference(last.time).abs() < repeatWindow) {
      return Future<void>.value();
    }
    _lastRecorded = (key: key, time: report.time);
    return _write(report);
  }

  Future<void> _write(CrashReport report) => _inTurn(() async {
    try {
      final file = await _file();
      final line = _encodeWithin(report, maxBytes);
      if (line == null) return;
      final lines = _newestWithin([...await _linesOrNone(file), line]);
      await _replace(file, lines);
    } on Object catch (e) {
      // Recording must never fail the error handler that called it.
      debugPrint('[shiori] crash log not written: $e');
    }
  });

  @override
  Future<List<CrashReport>> read() => _inTurn(() async {
    final file = await _file();
    if (!await file.exists()) return const <CrashReport>[];
    final lines = await file.readAsLines();
    return List.unmodifiable([for (final line in lines) ?_decode(line)]);
  });

  @override
  Future<void> clear() => _inTurn(() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  });

  /// The existing lines; a missing or unreadable file starts a new log.
  Future<List<String>> _linesOrNone(File file) async {
    try {
      if (!await file.exists()) return const [];
      return [
        for (final line in await file.readAsLines())
          if (line.trim().isNotEmpty) line,
      ];
    } on FileSystemException {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  /// The newest lines whose total size (with line breaks) fits [maxBytes].
  List<String> _newestWithin(List<String> lines) {
    var total = 0;
    var start = lines.length;
    while (start > 0) {
      final size = _bytes(lines[start - 1]);
      if (total + size > maxBytes) break;
      total += size;
      start--;
    }
    return lines.sublist(start);
  }

  Future<void> _replace(File file, List<String> lines) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(lines.map((l) => '$l\n').join(), flush: true);
    await temp.rename(file.path);
  }

  static int _bytes(String line) => utf8.encode(line).length + 1;

  static CrashReport? _decode(String line) {
    try {
      return CrashReport.tryFromJson(jsonDecode(line));
    } on FormatException {
      return null;
    }
  }

  /// [report] as one line no larger than [budget] bytes: long text is cut
  /// first, then the stack and context go, then the error is cut further.
  /// Null when not even the time and source fit.
  static String? _encodeWithin(CrashReport report, int budget) {
    final stack = report.stack?.split('\n');
    var kept = CrashReport(
      time: report.time,
      source: report.source,
      error: _cut(report.error, maxErrorChars),
      stack: stack == null || stack.length <= maxStackLines
          ? report.stack
          : [...stack.take(maxStackLines), '…'].join('\n'),
      context: report.context,
    );
    String encode(CrashReport r) => jsonEncode(r.toJson());
    if (_bytes(encode(kept)) <= budget) return encode(kept);

    kept = CrashReport(time: kept.time, source: kept.source, error: kept.error);
    var length = kept.error.length;
    while (_bytes(encode(kept)) > budget) {
      if (length == 0) return null;
      length ~/= 2;
      kept = CrashReport(
        time: kept.time,
        source: kept.source,
        error: _cut(report.error, length),
      );
    }
    return encode(kept);
  }

  static String _cut(String text, int length) =>
      text.length <= length ? text : '${text.substring(0, length)}…';
}
