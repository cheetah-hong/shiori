import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/backup/backup_labels.dart';
import 'package:shiori_core/shiori_core.dart';

/// Runs [work] behind a dialog that cannot be closed, showing [label].
Future<T> withProgress<T>(
  BuildContext context,
  String label,
  Future<T> Function() work,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: Space.md),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    navigator.pop();
  }
}

/// Asks before a restore with what the file holds. True for 복원.
Future<bool> askRestore(
  BuildContext context,
  BackupSummary summary, {
  required bool keepsCurrent,
}) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(BackupLabels.restoreQuestion),
      content: Text(
        [
          BackupLabels.madeBy(summary),
          BackupLabels.counts(summary),
          '',
          BackupLabels.restoreReplaces,
          if (keepsCurrent) BackupLabels.restoreKeeps,
        ].join('\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(BackupLabels.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: context.tokens.risk),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(BackupLabels.restoreConfirm),
        ),
      ],
    ),
  );
  return sure ?? false;
}

/// Asks before putting back the copy kept at [keptAt]. True for 되돌리기.
Future<bool> askUndo(BuildContext context, DateTime keptAt) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(BackupLabels.undoQuestion),
      content: Text(BackupLabels.undoDetail(keptAt)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(BackupLabels.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: context.tokens.risk),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(BackupLabels.undoConfirm),
        ),
      ],
    ),
  );
  return sure ?? false;
}

/// Says why nothing was restored (or undone); the data is as it was.
Future<void> showBackupFailure(
  BuildContext context,
  String title,
  String message,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text('$message\n\n${BackupLabels.unchanged}'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(BackupLabels.ok),
      ),
    ],
  ),
);
