// Dev-only screen preview: every screen on mock data, no login, no
// Firebase. Run with:
//
//   flutter run -d chrome -t lib/dev_preview/main_preview.dart
//
// The real app (lib/main.dart) never imports lib/dev_preview/, so none of
// this ships in it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preview_app.dart';
import 'preview_overrides.dart';

void main() {
  if (kReleaseMode) {
    throw StateError(
      'The dev preview is for debug builds only. Build the app from '
      'lib/main.dart.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(overrides: previewOverrides(), child: const PreviewApp()),
  );
}
