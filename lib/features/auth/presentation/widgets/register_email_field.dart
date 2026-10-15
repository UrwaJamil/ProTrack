import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/email_availability_controller.dart';
import '../../../../core/widgets/labeled_field.dart';
import 'email_availability_hint.dart';

/// The register screen's email field plus its debounced / on-blur
/// availability hint (CLAUDE.md §9).
class RegisterEmailField extends ConsumerStatefulWidget {
  const RegisterEmailField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<RegisterEmailField> createState() => _RegisterEmailFieldState();
}

class _RegisterEmailFieldState extends ConsumerState<RegisterEmailField> {
  final _focusNode = FocusNode();

  EmailAvailabilityController get _availability =>
      ref.read(emailAvailabilityControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _availability.checkNow(widget.controller.text);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Work email',
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'you@company.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            onChanged: _availability.onChanged,
            validator: (value) => (value == null || !value.contains('@'))
                ? 'Enter a valid email'
                : null,
          ),
        ),
        const EmailAvailabilityHint(),
      ],
    );
  }
}
