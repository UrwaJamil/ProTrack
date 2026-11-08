import 'package:flutter/material.dart';

import '../utils/date_format.dart';

/// A read-only field that opens the date picker. Takes part in [Form]
/// validation like any other field.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Select a date',
    this.validator,
    this.enabled = true,
    this.initialPickerDate,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String hint;
  final String? Function(DateTime? value)? validator;
  final bool enabled;

  /// Where the picker opens when [value] is null.
  final DateTime? initialPickerDate;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final _controller = TextEditingController(text: _text(widget.value));

  static String _text(DateTime? d) => d == null ? '' : formatDate(d);

  @override
  void didUpdateWidget(DateField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      // Setting the text notifies the enclosing Form, which must not be
      // marked dirty mid-build — sync once this frame is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.text = _text(widget.value);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? widget.initialPickerDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      widget.onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      enabled: widget.enabled,
      onTap: _pick,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.value),
    );
  }
}
