import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The text field whose placeholder is [hint]. Auth fields carry their
/// label above the field (outside it), so they're found by hint instead.
Finder fieldWithHint(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);
