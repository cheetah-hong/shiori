import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// A button of an [AlertDialog.adaptive]: an iOS alert action on Apple
/// platforms, a text button elsewhere. [destructive] says it in the risk
/// color.
Widget adaptiveDialogAction(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool destructive = false,
  bool isDefault = false,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: destructive,
      isDefaultAction: isDefault,
      child: Text(label),
    );
  }
  return TextButton(
    style: destructive
        ? TextButton.styleFrom(foregroundColor: context.tokens.risk)
        : null,
    onPressed: onPressed,
    child: Text(label),
  );
}
