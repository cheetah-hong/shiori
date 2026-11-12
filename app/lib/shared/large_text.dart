import 'package:flutter/widgets.dart';

/// From about the iOS AX1 text size every screen stacks what sits side by
/// side at the default size (bar buttons, reveal buttons, a value beside
/// its label). One threshold for the whole app.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(_probe) >= _probe * _largeFactor;

const double _probe = 16;
const double _largeFactor = 1.6;
