import 'package:flutter/material.dart';

/// Breakpoint for switching between mobile (bottom nav) and desktop/web
/// (sidebar nav) layouts.
class Breakpoints {
  Breakpoints._();

  /// At or above this width the app shows sidebar navigation; below it,
  /// a bottom navigation bar.
  static const double wide = 700;
}

bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.wide;
