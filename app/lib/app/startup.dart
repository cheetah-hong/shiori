/// Wiring done once before the first frame.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shiori/adapters/app_database.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// How long finding the app support folder may take before startup goes on
/// without a database.
const databaseOpenTimeout = Duration(seconds: 10);

/// The override that plugs the opened database into [appDatabaseProvider].
///
/// Never throws: if the folder cannot be found or created, the error is
/// logged and the provider rethrows it, so the screens show their load error
/// state instead of the app never starting.
Future<Override> appDatabaseOverride({
  Future<ShioriDatabase> Function() open = openAppDatabase,
  Duration timeout = databaseOpenTimeout,
}) async {
  try {
    final database = await open().timeout(timeout);
    return appDatabaseProvider.overrideWithValue(database);
  } on Object catch (error, stack) {
    debugPrint('[shiori] could not open the database: $error\n$stack');
    return appDatabaseProvider.overrideWith(
      (ref) => Error.throwWithStackTrace(error, stack),
    );
  }
}
