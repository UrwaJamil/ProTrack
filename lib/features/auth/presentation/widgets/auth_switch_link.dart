import 'package:flutter/material.dart';

/// Bottom "Don't have an account? **Create new account**" style link: the
/// whole line is tappable, with the [action] part bold in the accent color.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Text.rich(
          TextSpan(
            text: '$prompt ',
            style: TextStyle(color: colors.onSurfaceVariant),
            children: [
              TextSpan(
                text: action,
                style: TextStyle(
                  color: colors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
