import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import '../data/app_user.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/role_toggle.dart';

/// One-time role picker after a first Google sign-in (CLAUDE.md §9),
/// since Google doesn't collect a `defaultRole`. The router keeps the user
/// here while [AuthStatus.needsRole] and moves on once the state changes.
class ChooseRoleScreen extends ConsumerStatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  ConsumerState<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends ConsumerState<ChooseRoleScreen> {
  UserRole _role = UserRole.leader;
  bool _submitting = false;
  String? _error;

  AuthController get _auth => ref.read(authControllerProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final who = user?.displayName ?? user?.email;

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            who == null ? 'One last step' : 'Welcome, $who',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'How will you mostly use the app? This picks the dashboard you '
            'land on. Your role inside each project is set by that project.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          RoleToggle(
            value: _role,
            onChanged: (role) => setState(() => _role = role),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting
                ? null
                : () => _run(() => _auth.completeGoogleSignup(_role)),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _submitting
                ? null
                : () => _run(_auth.cancelGoogleSignup),
            child: const Text('Cancel and sign out'),
          ),
        ],
      ),
    );
  }
}
