import 'package:flutter/material.dart';

import '../../../../core/responsive.dart';
import '../../../../core/widgets/app_logo.dart';

const appTagline = 'Project management for high-velocity teams';

/// Shared layout for the auth screens: logo, app name and tagline on top,
/// the form [child] in a card (at every width), and an optional [footer]
/// (e.g. the login/register switch link) centred below the card.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final wide = isWideScreen(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 24 : 16,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthHeader(),
                  const SizedBox(height: 28),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 32 : 20),
                      child: child,
                    ),
                  ),
                  if (footer != null) ...[const SizedBox(height: 20), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const AppLogo(),
        const SizedBox(height: 16),
        Text(
          appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          appTagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
