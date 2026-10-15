import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.calendar_month_outlined,
      message:
          'Calendar View\n(all task deadlines across all projects)\ncoming in a later phase',
    );
  }
}
