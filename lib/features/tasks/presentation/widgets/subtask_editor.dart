import 'package:flutter/material.dart';

import '../../data/task.dart';

/// FR-3.5: the Admin breaks a task into portions. One text field per
/// subtask with a remove button, plus "Add subtask". Blank rows are
/// dropped from what [onChanged] reports; existing `done` flags are kept.
class SubtaskEditor extends StatefulWidget {
  const SubtaskEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Subtask> initial;
  final ValueChanged<List<Subtask>> onChanged;
  final bool enabled;

  @override
  State<SubtaskEditor> createState() => _SubtaskEditorState();
}

class _Entry {
  _Entry(String title, this.done)
    : controller = TextEditingController(text: title);

  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  final bool done;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _SubtaskEditorState extends State<SubtaskEditor> {
  late final List<_Entry> _entries = [
    for (final s in widget.initial) _Entry(s.title, s.done),
  ];

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _notify() => widget.onChanged([
    for (final e in _entries)
      if (e.controller.text.trim().isNotEmpty)
        Subtask(title: e.controller.text.trim(), done: e.done),
  ]);

  void _add() {
    final entry = _Entry('', false);
    setState(() => _entries.add(entry));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) entry.focus.requestFocus();
    });
  }

  void _remove(_Entry entry) {
    setState(() => _entries.remove(entry));
    entry.dispose();
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, entry) in _entries.indexed)
          Padding(
            key: ObjectKey(entry),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.controller,
                    focusNode: entry.focus,
                    enabled: widget.enabled,
                    maxLength: subtaskTitleMaxLength,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _notify(),
                    decoration: InputDecoration(
                      hintText: 'Subtask ${i + 1}',
                      counterText: '',
                      prefixIcon: Icon(
                        entry.done
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Remove subtask ${i + 1}',
                  onPressed: widget.enabled ? () => _remove(entry) : null,
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.enabled && _entries.length < maxSubtasks
                ? _add
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add subtask'),
          ),
        ),
      ],
    );
  }
}
