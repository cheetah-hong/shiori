import 'package:shiori_core/src/backup/backup_data.dart';

/// Block slot: everything a backup holds, read and replaced at once.
///
/// Blocks: `DriftBackupStore` (app).
abstract interface class BackupStore {
  /// Every word, playlist, entry, card, press and study option, read in one
  /// transaction (no write lands between the tables).
  Future<BackupData> read();

  /// Replaces everything with [data] in one transaction: on any error the
  /// stored data is as it was. [data] is already checked (`decodeBackup`).
  Future<void> replaceAll(BackupData data);
}
