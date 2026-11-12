import 'dart:typed_data';

/// Block slot: the one copy of the learner's data kept inside the app just
/// before a restore, so the restore can be undone (설정 › 복원 전으로
/// 되돌리기).
///
/// Blocks: `FileBackupKeeper` (app), a map in tests.
abstract interface class BackupKeeper {
  /// Keeps [bytes] (a backup file) in place of the copy kept before. Either
  /// the whole new copy is kept or the error reaches the caller.
  Future<void> keep(Uint8List bytes);

  /// The kept copy; null when there is none.
  Future<Uint8List?> read();

  /// When the kept copy was kept; null when there is none.
  Future<DateTime?> keptAt();

  /// Removes the kept copy (nothing when there is none).
  Future<void> discard();
}
