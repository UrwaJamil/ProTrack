import 'package:flutter/material.dart';

import '../../reports/presentation/analytics_body.dart';

/// Full-screen page, opened from the Admin's Profile tab.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & reports')),
      body: const AnalyticsBody(),
    );
  }
}
