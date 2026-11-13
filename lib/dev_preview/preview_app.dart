import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../app/theme_mode_controller.dart';
import 'preview_router.dart';

/// The real app's themes and theme mode on the preview router, with a
/// floating "Screens" button on every screen to get back to the list.
class PreviewApp extends ConsumerWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(previewRouterProvider);
    return MaterialApp.router(
      title: 'ProTrack preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      builder: (context, child) => Stack(
        children: [
          ?child,
          _BackToListButton(router: router),
        ],
      ),
    );
  }
}

class _BackToListButton extends StatelessWidget {
  const _BackToListButton({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        if (path == previewHomePath) return const SizedBox.shrink();
        return Positioned(
          left: 12,
          bottom: 96,
          child: Material(
            color: colors.secondary,
            shape: const StadiumBorder(),
            elevation: 3,
            child: InkWell(
              key: const ValueKey('preview-back-to-list'),
              customBorder: const StadiumBorder(),
              onTap: () => router.go(previewHomePath),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_list, size: 16, color: colors.onSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Screens',
                      style: TextStyle(
                        color: colors.onSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
