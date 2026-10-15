import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

class TeamMembersScreen extends StatelessWidget {
  const TeamMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.groups_outlined,
      message:
          'Members & Skills\n(skill tags, "On Leave" badges)\ncoming in a later phase',
    );
  }
}
