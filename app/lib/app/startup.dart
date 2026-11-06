/// Wiring done once before the first frame.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shiori/adapters/app_database.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// How long finding the app support folder may take before startup goes on
/// without a database.
const databaseOpenTimeout = Duration(seconds: 10);

/// The override that plugs the database file into [appDatabaseProvider].
///
/// The file is found once ([locate], within [timeout]). Each time the
/// provider is built it [open]s a new connection and closes it when it is
/// rebuilt: invalidating [appDatabaseProvider] (the screens' 「다시
/// 불러오기」) tries again on a fresh connection, which is what a failed
/// migration needs (a connection keeps its open error).
///
/// Never throws: if the folder cannot be found or created, the error is
/// logged and the provider rethrows it, so the screens show their load error
/// state instead of the app never starting.
Future<Override> appDatabaseOverride({
  Future<File> Function() locate = appDatabaseFile,
  ShioriDatabase Function(File file) open = ShioriDatabase.file,
  Duration timeout = databaseOpenTimeout,
}) async {
  try {
    final file = await locate().timeout(timeout);
    return appDatabaseProvider.overrideWith((ref) {
      final database = open(file);
      ref.onDispose(() => unawaited(database.close()));
      return database;
    });
  } on Object catch (error, stack) {
    debugPrint('[shiori] could not find the database folder: $error\n$stack');
    return appDatabaseProvider.overrideWith(
      (ref) => Error.throwWithStackTrace(error, stack),
    );
  }
}

/// The override that plugs the bundled dictionary in once it is open.
///
/// Opening starts right away but is not awaited: the first frame never waits
/// for unpacking, and until it is done the dictionary slot stays empty.
Override bundledDictionaryOverride({
  Future<BundledDictionary> Function() open = openAppDictionary,
}) {
  final opening = open();
  return bundledDictionaryProvider.overrideWith((ref) {
    ref.onDispose(
      () => unawaited(opening.then((d) => d.close(), onError: (_) {})),
    );
    return opening;
  });
}

/// The override that plugs the bundled Korean glossary in once it is open
/// (as [bundledDictionaryOverride]: started now, never awaited).
Override bundledGlossaryOverride({
  Future<BundledGlossary> Function() open = openAppGlossary,
}) {
  final opening = open();
  return bundledGlossaryProvider.overrideWith((ref) {
    ref.onDispose(
      () => unawaited(opening.then((g) => g.close(), onError: (_) {})),
    );
    return opening;
  });
}
