import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps a folder of the app out of the device backup (iCloud, computer):
/// for files the app can lose without harm, such as the crash log. The
/// learning database is never excluded; the backup is what keeps it safe.
abstract interface class BackupExclusion {
  /// Marks [directory], and so everything in it, as left out of backups.
  /// Throws when the platform cannot.
  Future<void> exclude(Directory directory);
}

/// iOS: `URLResourceValues.isExcludedFromBackup` through the
/// `shiori/backup` channel (`BackupChannel.swift`), which accepts only paths
/// inside the app's container.
final class ChannelBackupExclusion implements BackupExclusion {
  const ChannelBackupExclusion();

  static const MethodChannel channel = MethodChannel('shiori/backup');

  @override
  Future<void> exclude(Directory directory) =>
      channel.invokeMethod<void>('exclude', {'path': directory.path});

  /// Whether [path] itself carries the mark (not whether a parent does).
  Future<bool> isExcluded(String path) async =>
      await channel.invokeMethod<bool>('isExcluded', {'path': path}) ?? false;
}

/// Android: nothing to mark, the manifest turns backups off for the whole
/// app (`android:allowBackup="false"`).
final class NoBackupExclusion implements BackupExclusion {
  const NoBackupExclusion();

  @override
  Future<void> exclude(Directory directory) async {}
}

/// The exclusion this platform uses.
BackupExclusion backupExclusionFor({required bool isIOS}) =>
    isIOS ? const ChannelBackupExclusion() : const NoBackupExclusion();
