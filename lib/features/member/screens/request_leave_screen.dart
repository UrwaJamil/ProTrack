import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

class RequestLeaveScreen extends StatelessWidget {
  const RequestLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderContent(
      icon: Icons.beach_access_outlined,
      message: 'Request Leave\n(date range + reason)\ncoming in a later phase',
    );
  }
}
