import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.checklist_outlined,
      message: 'My Tasks\n(across all projects, sorted by deadline)\ncoming in Phase 3',
    );
  }
}
