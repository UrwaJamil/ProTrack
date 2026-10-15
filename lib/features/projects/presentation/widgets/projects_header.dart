import 'package:flutter/material.dart';

import 'project_status_badge.dart';

/// "Projects" + "Admin View" badge, or "My Projects" for Members.
class ProjectsHeader extends StatelessWidget {
  const ProjectsHeader({super.key, required this.adminView});

  final bool adminView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            adminView ? 'Projects' : 'My Projects',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (adminView) ...[
          const SizedBox(width: 10),
          const LabelPill(label: 'Admin View'),
        ],
      ],
    );
  }
}
