import 'dart:async';
import 'dart:typed_data';

import 'package:shiori_core/src/backup/backup_codec.dart';
import 'package:shiori_core/src/ports/backup_keeper.dart';
import 'package:shiori_core/src/ports/backup_store.dart';
import 'package:shiori_core/src/ports/clock.dart';

/// Runs [work] (encoding or checking a large file) somewhere it does not
/// hold up the screen: `Isolate.run` in the app, right here in tests.
typedef BackupWork = Future<R> Function<R>(FutureOr<R> Function() work);

/// Runs [work] here.
Future<R> backupWorkHere<R>(FutureOr<R> Function() work) async => work();

/// A backup file ready to hand to the share sheet.
final class BackupExport {
  const BackupExport({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// The copy kept before a restore could not be written, so nothing was
/// restored.
final class BackupNotKeptException implements Exception {
  const BackupNotKeptException(this.cause);

  final Object cause;

  @override
  String toString() => 'BackupNotKeptException($cause)';
}

/// 설정 › 백업: makes a backup file of everything stored, checks a picked
/// file, and replaces everything with it, keeping the data from just before
/// so the restore can be undone.
final class BackupService {
  BackupService({
    required BackupStore store,
    required BackupKeeper keeper,
    required Clock clock,
    required Future<BackupApp> Function() app,
    BackupWork work = backupWorkHere,
    int maxBytes = backupMaxBytes,
    int maxLevel = backupMaxLevel,
  }) : _store = store,
       _keeper = keeper,
       _clock = clock,
       _app = app,
       _work = work,
       _maxBytes = maxBytes,
       _maxLevel = maxLevel;

  final BackupStore _store;
  final BackupKeeper _keeper;
  final Clock _clock;
  final Future<BackupApp> Function() _app;
  final BackupWork _work;
  final int _maxBytes;
  final int _maxLevel;

  /// Everything stored, as a backup file named after now. A
  /// [BackupException] ([BackupProblem.tooLarge]) when it would be over the
  /// limit.
  Future<BackupExport> export() async {
    final file = BackupFile(
      createdAt: _clock.now(),
      app: await _app(),
      data: await _store.read(),
    );
    final maxBytes = _maxBytes;
    final maxLevel = _maxLevel;
    // Only plain values go to the worker (it may be another isolate).
    final bytes = await _work(() => _checkedBytes(file, maxBytes, maxLevel));
    return BackupExport(fileName: backupFileName(file.createdAt), bytes: bytes);
  }

  /// The backup in [bytes], checked; a [BackupException] when it cannot be
  /// restored.
  Future<BackupFile> open(List<int> bytes) {
    final maxBytes = _maxBytes;
    final maxLevel = _maxLevel;
    return _work(
      () => decodeBackup(bytes, maxBytes: maxBytes, maxLevel: maxLevel),
    );
  }

  /// Whether anything is stored that a restore would replace (a word,
  /// playlist, card or press); when not, a restore keeps no copy.
  Future<bool> hasData() async => !(await _store.read()).isEmpty;

  /// Keeps what is stored now (unless nothing is), then replaces it with
  /// [file]. When the copy cannot be kept, a [BackupNotKeptException] and
  /// nothing is restored.
  Future<void> restore(BackupFile file) async {
    final now = await _store.read();
    if (!now.isEmpty) {
      final kept = BackupFile(
        createdAt: _clock.now(),
        app: await _app(),
        data: now,
      );
      try {
        // Not limited by the size: the copy is never refused when put back.
        await _keeper.keep(
          await _work(() => encodeBackup(kept, maxBytes: _unlimited)),
        );
      } on Object catch (e) {
        throw BackupNotKeptException(e);
      }
    }
    await _store.replaceAll(file.data);
  }

  /// When the copy from before the last restore was kept; null when none.
  Future<DateTime?> keptAt() => _keeper.keptAt();

  /// Puts back the copy kept before the last restore and removes it. A
  /// [StateError] when there is none; a [BackupException] when it cannot be
  /// read.
  Future<void> undoRestore() async {
    final bytes = await _keeper.read();
    if (bytes == null) throw StateError('no copy kept before a restore');
    final maxLevel = _maxLevel;
    final kept = await _work(
      () => decodeBackup(bytes, maxBytes: _unlimited, maxLevel: maxLevel),
    );
    await _store.replaceAll(kept.data);
    await _keeper.discard();
  }
}

/// The kept copy is the learner's own data, written by this app: no size
/// limit applies to it.
const int _unlimited = 1 << 62;

/// [file] encoded, then read back the way a restore reads it: an export
/// never hands out a file a restore would refuse.
Uint8List _checkedBytes(BackupFile file, int maxBytes, int maxLevel) {
  final bytes = encodeBackup(file, maxBytes: maxBytes);
  decodeBackup(bytes, maxBytes: maxBytes, maxLevel: maxLevel);
  return bytes;
}
