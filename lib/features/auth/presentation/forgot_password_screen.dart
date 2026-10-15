import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../../../core/widgets/labeled_field.dart';
import 'widgets/auth_scaffold.dart';

const passwordResetSentMessage =
    'If an account exists for this email, a reset link has been sent. '
    'Check your inbox and spam folder.';

final _plausibleEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Password reset request (CLAUDE.md §9). [initialEmail] arrives via
/// go_router's `extra`, never the URL, so the address stays out of browser
/// history.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendPasswordReset(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyResetError(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      footer: Center(
        child: TextButton.icon(
          onPressed: _sending ? null : _backToLogin,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to login'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset your password',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_sent)
            _SentNotice(onSendAgain: () => setState(() => _sent = false))
          else
            _buildForm(theme),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Enter your account's email and we'll send you a link to choose "
            'a new password.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'Work email',
            child: TextFormField(
              controller: _emailController,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'you@company.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) =>
                  _plausibleEmail.hasMatch((value ?? '').trim())
                  ? null
                  : 'Enter a valid email',
              onFieldSubmitted: (_) => _send(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }
}

class _SentNotice extends StatelessWidget {
  const _SentNotice({required this.onSendAgain});

  final VoidCallback onSendAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 40,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          passwordResetSentMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onSendAgain, child: const Text('Send again')),
      ],
    );
  }
}

String _friendlyResetError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    default:
      return "We couldn't send the reset link. Please try again.";
  }
}
