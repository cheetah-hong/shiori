import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/adapters/backup_files.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/backup/backup_dialogs.dart';
import 'package:shiori/features/backup/backup_labels.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// 설정 › 백업: 백업 파일 만들기 (to the share sheet), 백업에서 복원 (from
/// the file picker, after a question with the file's summary), and 복원
/// 전으로 되돌리기 while a copy from before a restore is kept. Rows are off
/// while one of them runs.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Where the tapped row is on screen (the iPad share popover's anchor).
  static Rect? _originOf(BuildContext row) {
    final box = row.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _export(Rect? origin) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    final share = ref.read(backupShareProvider);
    try {
      final file = await service.export();
      final result = await share(file, origin);
      if (result == BackupShareResult.shared) {
        _say(messenger, const SnackBar(content: Text(BackupLabels.exported)));
      }
    } on BackupException catch (e) {
      debugPrint('backup export refused: $e');
      _say(
        messenger,
        SnackBar(
          content: Text(
            e.problem == BackupProblem.tooLarge
                ? BackupLabels.exportTooLarge
                : BackupLabels.exportFailed,
          ),
        ),
      );
    } on Exception catch (e, stack) {
      debugPrint('backup export failed: $e\n$stack');
      _say(messenger, const SnackBar(content: Text(BackupLabels.exportFailed)));
    }
  }

  Future<void> _restore() async {
    final service = ref.read(backupServiceProvider);
    final List<int>? bytes;
    try {
      bytes = await ref.read(backupPickerProvider)();
    } on BackupException catch (e) {
      return _failed(BackupLabels.problem(e.problem), e);
    } on Exception catch (e) {
      return _failed(BackupLabels.pickFailed, e);
    }
    if (bytes == null || !mounted) return;

    final BackupFile file;
    try {
      file = await withProgress(
        context,
        BackupLabels.checking,
        () => service.open(bytes!),
      );
    } on BackupException catch (e) {
      return _failed(BackupLabels.problem(e.problem), e);
    } on Exception catch (e) {
      return _failed(BackupLabels.pickFailed, e);
    }
    final bool keepsCurrent;
    try {
      keepsCurrent = await service.hasData();
    } on Exception catch (e) {
      return _failed(BackupLabels.restoreBroke, e);
    }
    if (!mounted) return;
    final sure = await askRestore(
      context,
      file.summary,
      keepsCurrent: keepsCurrent,
    );
    if (!sure || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await withProgress(
        context,
        BackupLabels.restoring,
        () => service.restore(file),
      );
    } on BackupNotKeptException catch (e) {
      return _failed(BackupLabels.notKept, e);
    } on Exception catch (e) {
      return _failed(BackupLabels.restoreBroke, e);
    }
    _refresh();
    _say(
      messenger,
      SnackBar(content: Text(BackupLabels.restored(file.summary))),
    );
  }

  Future<void> _undo(DateTime keptAt) async {
    final service = ref.read(backupServiceProvider);
    final sure = await askUndo(context, keptAt);
    if (!sure || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await withProgress(context, BackupLabels.undoing, service.undoRestore);
    } on BackupException catch (e) {
      return _failed(
        BackupLabels.problem(e.problem),
        e,
        title: BackupLabels.undoFailed,
      );
    } on Exception catch (e) {
      return _failed(
        BackupLabels.restoreBroke,
        e,
        title: BackupLabels.undoFailed,
      );
    }
    _refresh();
    _say(messenger, const SnackBar(content: Text(BackupLabels.undone)));
  }

  /// Shows [bar] at once, in place of any message still showing.
  static void _say(ScaffoldMessengerState messenger, SnackBar bar) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(bar);

  /// Every screen reads the replaced data again.
  void _refresh() {
    ref.invalidate(studyPreferencesProvider);
    ref.read(dataRevisionProvider.notifier).bump();
  }

  Future<void> _failed(
    String message,
    Object error, {
    String title = BackupLabels.restoreFailed,
  }) async {
    debugPrint('backup restore: $error');
    if (!mounted) return;
    await showBackupFailure(context, title, message);
  }

  @override
  Widget build(BuildContext context) {
    final keptAt = ref.watch(backupKeptAtProvider).value;
    final enabled = !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(BackupLabels.section),
        Builder(
          builder: (row) => ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: enabled,
            leading: const Icon(Icons.ios_share),
            title: const Text(BackupLabels.export),
            subtitle: const Text(BackupLabels.exportHint),
            onTap: () => unawaited(_run(() => _export(_originOf(row)))),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: enabled,
          leading: const Icon(Icons.settings_backup_restore),
          title: const Text(BackupLabels.restore),
          subtitle: const Text(BackupLabels.restoreHint),
          onTap: () => unawaited(_run(_restore)),
        ),
        if (keptAt != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: enabled,
            leading: const Icon(Icons.undo),
            title: const Text(BackupLabels.undo),
            subtitle: Text(BackupLabels.kept(keptAt)),
            onTap: () => unawaited(_run(() => _undo(keptAt))),
          ),
        Padding(
          padding: const EdgeInsets.only(top: Space.xs, bottom: Space.md),
          child: Text(BackupLabels.leftOut, style: context.text.bodySmall),
        ),
      ],
    );
  }
}
