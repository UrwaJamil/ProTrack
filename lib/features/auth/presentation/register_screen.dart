import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../data/app_user.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_switch_link.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/register_email_field.dart';
import 'widgets/register_password_field.dart';
import 'widgets/role_toggle.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.leader;
  bool _submitting = false;
  String? _error;

  /// Create account stays disabled until the password meets every rule.
  bool _passwordOk = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_passwordOk) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            defaultRole: _role,
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
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
    return AuthScaffold(
      footer: AuthSwitchLink(
        prompt: 'Already have an account?',
        action: 'Log in',
        onPressed: () => context.go('/login'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoleToggle(
              value: _role,
              onChanged: (role) => setState(() => _role = role),
            ),
            const SizedBox(height: 20),
            LabeledField(
              label: 'Full name',
              child: TextFormField(
                controller: _nameController,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'Jane Doe',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            RegisterEmailField(controller: _emailController),
            const SizedBox(height: 16),
            RegisterPasswordField(
              controller: _passwordController,
              onCheckChanged: (check) =>
                  setState(() => _passwordOk = check.meetsPolicy),
              onSubmitted: _submit,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Create Account',
              busy: _submitting,
              onPressed: _passwordOk ? _submit : null,
            ),
            GoogleSignInSection(
              enabled: !_submitting,
              onError: (message) => setState(() => _error = message),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'weak-password':
      return 'Please choose a stronger password.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    default:
      return e.message ?? 'Registration failed. Please try again.';
  }
}
