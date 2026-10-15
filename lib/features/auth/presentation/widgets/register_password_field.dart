import 'package:flutter/material.dart';

import '../../application/password_policy.dart';
import '../../../../core/widgets/labeled_field.dart';
import 'password_strength_indicator.dart';

/// The register screen's password field with its live strength indicator.
/// Reports each new [PasswordCheck] (never the password itself) through
/// [onCheckChanged] so the screen can enable Create account.
class RegisterPasswordField extends StatefulWidget {
  const RegisterPasswordField({
    super.key,
    required this.controller,
    required this.onCheckChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<PasswordCheck> onCheckChanged;
  final VoidCallback onSubmitted;

  @override
  State<RegisterPasswordField> createState() => _RegisterPasswordFieldState();
}

class _RegisterPasswordFieldState extends State<RegisterPasswordField> {
  bool _obscure = true;
  late PasswordCheck _check = evaluatePassword(widget.controller.text);

  void _onChanged(String password) {
    final check = evaluatePassword(password);
    setState(() => _check = check);
    widget.onCheckChanged(check);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Password',
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              hintText: 'Create a strong password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: _onChanged,
            validator: (value) => evaluatePassword(value ?? '').meetsPolicy
                ? null
                : 'Password doesn\'t meet all the requirements below',
            onFieldSubmitted: (_) => widget.onSubmitted(),
          ),
        ),
        PasswordStrengthIndicator(check: _check),
      ],
    );
  }
}
