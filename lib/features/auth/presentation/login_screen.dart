import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_switch_link.dart';
import 'widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
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
    // Why the user was signed out, if it wasn't their choice (e.g. their
    // registration never finished writing users/{uid}).
    final error = _error ?? ref.watch(authControllerProvider).message;
    return AuthScaffold(
      footer: AuthSwitchLink(
        prompt: "Don't have an account?",
        action: 'Create new account',
        onPressed: () => context.go('/register'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Work email',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'you@company.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Password',
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  hintText: 'Your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your password'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            _ForgotPasswordLink(
              emailController: _emailController,
              enabled: !_submitting,
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Log In',
              busy: _submitting,
              onPressed: _submit,
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

class _ForgotPasswordLink extends StatelessWidget {
  const _ForgotPasswordLink({
    required this.emailController,
    required this.enabled,
  });

  final TextEditingController emailController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        // Pre-fill via `extra`, not the URL, so the email stays out of
        // browser history.
        onPressed: enabled
            ? () => context.push(
                '/forgot-password',
                extra: emailController.text.trim(),
              )
            : null,
        child: const Text('Forgot password?'),
      ),
    );
  }
}

String _friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    default:
      return e.message ?? 'Login failed. Please try again.';
  }
}
