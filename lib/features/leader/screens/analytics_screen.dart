import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

/// Full-screen page, opened from the Admin's Profile tab.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & reports')),
      body: const PlaceholderContent(
        icon: Icons.insights_outlined,
        message: 'Analytics/Reports\n(team performance, overdue tasks, workload)\ncoming in a later phase',
      ),
    );
  }
}
