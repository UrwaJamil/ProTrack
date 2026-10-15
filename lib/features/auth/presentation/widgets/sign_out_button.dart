import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controller.dart';

/// A clear, discoverable sign-out action (FR-1.5), shown on the Profile
/// tab. Confirms before actually signing out, to guard against stray taps.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: error),
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text("You'll need to log in again to continue."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          await ref.read(authControllerProvider.notifier).signOut();
        }
      },
    );
  }
}
