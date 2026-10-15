import 'package:flutter/material.dart';

import '../../../../core/widgets/date_field.dart';
import '../../../../core/widgets/labeled_field.dart';

const projectNameMaxLength = 100;
const projectDescriptionMaxLength = 500;

/// "Deadline must be after the start date" — the same rule Firestore
/// enforces.
String? validateDeadline(DateTime? start, DateTime? deadline) {
  if (deadline == null) return 'Pick a deadline';
  if (start != null && !deadline.isAfter(start)) {
    return 'Deadline must be after the start date';
  }
  return null;
}

/// Name, description and the two dates, labels above each field.
class ProjectFormFields extends StatelessWidget {
  const ProjectFormFields({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.startDate,
    required this.deadline,
    required this.onStartChanged,
    required this.onDeadlineChanged,
    this.enabled = true,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final DateTime? startDate;
  final DateTime? deadline;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onDeadlineChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Project name',
          child: TextFormField(
            controller: nameController,
            enabled: enabled,
            maxLength: projectNameMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Mobile App Redesign',
              prefixIcon: Icon(Icons.folder_outlined),
              counterText: '',
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter a project name'
                : null,
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Description',
          child: TextFormField(
            controller: descriptionController,
            enabled: enabled,
            minLines: 3,
            maxLines: 6,
            maxLength: projectDescriptionMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What is this project about?',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LabeledField(
          label: 'Start date',
          child: DateField(
            value: startDate,
            enabled: enabled,
            onChanged: onStartChanged,
            validator: (d) => d == null ? 'Pick a start date' : null,
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Deadline',
          child: DateField(
            value: deadline,
            enabled: enabled,
            onChanged: onDeadlineChanged,
            initialPickerDate: startDate?.add(const Duration(days: 30)),
            validator: (d) => validateDeadline(startDate, d),
          ),
        ),
      ],
    );
  }
}
