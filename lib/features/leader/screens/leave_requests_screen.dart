import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

class LeaveRequestsScreen extends StatelessWidget {
  const LeaveRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.event_busy_outlined,
      message: 'Leave Requests\n(approve/reject)\ncoming in a later phase',
    );
  }
}
