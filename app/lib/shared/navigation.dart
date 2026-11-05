import 'package:flutter/material.dart';

/// Pushes [screen], first clearing any snack bar so it cannot cover the next
/// screen's controls (the study buttons sit where snack bars float).
Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
  return Navigator.of(
    context,
  ).push<T>(MaterialPageRoute<T>(builder: (_) => screen));
}
