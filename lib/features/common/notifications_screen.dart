import 'package:flutter/material.dart';

import 'placeholder_content.dart';

/// Full-screen page opened from the app bar bell, shared by Admin (leader)
/// and Member — the notification center doesn't differ by role until real
/// data is wired up (Phase 8).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const PlaceholderContent(
        icon: Icons.notifications_outlined,
        message: 'Notifications\ncoming in a later phase',
      ),
    );
  }
}
