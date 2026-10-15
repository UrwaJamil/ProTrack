import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

class ProjectChatScreen extends StatelessWidget {
  const ProjectChatScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat: $projectId')),
      body: const PlaceholderContent(
        icon: Icons.chat_outlined,
        message:
            'Project Chat\n(one dedicated chat per project)\ncoming in a later phase',
      ),
    );
  }
}
