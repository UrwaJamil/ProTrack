import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../application/auth_controller.dart';
import '../../data/auth_repository.dart';

/// "OR CONTINUE WITH" divider, "Continue with Google" and the trust line,
/// shared by the login and register screens (CLAUDE.md §9). On platforms
/// without Google Sign-In support only the trust line shows. Failures are
/// reported through [onError] so each screen shows them in its usual error
/// slot.
class GoogleSignInSection extends ConsumerStatefulWidget {
  const GoogleSignInSection({
    super.key,
    required this.onError,
    this.enabled = true,
  });

  /// Called with a user-facing message, or `null` when a new attempt starts.
  final ValueChanged<String?> onError;

  /// False while the screen's own primary action is running.
  final bool enabled;

  @override
  ConsumerState<GoogleSignInSection> createState() =>
      _GoogleSignInSectionState();
}

class _GoogleSignInSectionState extends ConsumerState<GoogleSignInSection> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    widget.onError(null);
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (e) {
      authLog('Google sign-in failed: $e');
      if (mounted) widget.onError(googleSignInErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(authRepositoryProvider).supportsGoogleSignIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (supported) ...[
          const SizedBox(height: 24),
          const _OrDivider(),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: (_busy || !widget.enabled) ? null : _signIn,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const GoogleLogo(size: 18),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Continue with Google',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const _TrustLine(),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Encrypted connection (TLS)',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Google's four-color "G", drawn rather than shipped as an asset. Its
/// colors are Google's brand colors, deliberately not theme tokens.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    double rad(double degrees) => degrees * math.pi / 180;
    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Angles: 0° = 3 o'clock, clockwise. The gap at -40°..0° is the
    // opening of the G.
    canvas
      ..drawArc(rect, rad(-140), rad(100), false, arc(_red))
      ..drawArc(rect, rad(145), rad(75), false, arc(_yellow))
      ..drawArc(rect, rad(45), rad(100), false, arc(_green))
      ..drawArc(rect, rad(0), rad(45), false, arc(_blue))
      // The crossbar.
      ..drawRect(
        Rect.fromLTRB(
          size.width / 2,
          size.height / 2 - stroke / 2,
          size.width,
          size.height / 2 + stroke / 2,
        ),
        Paint()..color = _blue,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String googleSignInErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'account-exists-with-different-credential' =>
        'An account already exists for this email. '
            'Log in with your password instead.',
      'popup-blocked' =>
        'Your browser blocked the sign-in popup. Allow popups and try again.',
      'operation-not-allowed' =>
        "Google sign-in isn't enabled for this app yet.",
      'user-disabled' => 'This account has been disabled.',
      'network-request-failed' =>
        'Network error. Check your connection and try again.',
      _ => 'Google sign-in failed. Please try again.',
    };
  }
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        "Google sign-in isn't configured for this app yet.",
      _ => 'Google sign-in failed. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
