import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Chips for the current skill tags (tap × to remove) plus a field to add
/// one. Purely presentational: the parent owns the list and saves it.
class SkillTagsEditor extends StatefulWidget {
  const SkillTagsEditor({
    super.key,
    required this.tags,
    required this.onChanged,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<SkillTagsEditor> createState() => _SkillTagsEditorState();
}

class _SkillTagsEditorState extends State<SkillTagsEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = raw.trim();
    _controller.clear();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Skill tags', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.tags)
              Chip(
                label: Text(tag),
                backgroundColor: appColors.chipBackground,
                labelStyle: TextStyle(color: appColors.chipText),
                deleteIconColor: appColors.chipText,
                onDeleted: () => widget.onChanged(
                  widget.tags.where((t) => t != tag).toList(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Add a skill tag',
            hintText: 'e.g. Graphic Designer',
            prefixIcon: Icon(Icons.add_outlined),
          ),
          onSubmitted: _add,
        ),
      ],
    );
  }
}
