import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../application/projects_providers.dart';
import 'widgets/project_card_skeleton.dart';
import 'widgets/project_list.dart';
import 'widgets/projects_header.dart';

/// Projects tab for both roles (FR-2.4). [adminView] is the Admin
/// dashboard: "Admin View" badge, All/My Projects toggle and the
/// New Project button. Members see only their assigned projects.
class ProjectsOverviewScreen extends ConsumerWidget {
  const ProjectsOverviewScreen({super.key, required this.adminView});

  final bool adminView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(myProjectsProvider);
    return Scaffold(
      floatingActionButton: adminView
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/leader/projects/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            )
          : null,
      body: projects.when(
        loading: () => _Loading(adminView: adminView),
        error: (error, _) => ErrorState(
          message: "We couldn't load your projects.",
          onRetry: () => ref.invalidate(myProjectsProvider),
        ),
        data: (projects) =>
            ProjectList(projects: projects, adminView: adminView),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.adminView});

  final bool adminView;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProjectsHeader(adminView: adminView),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++) ...[
          const ProjectCardSkeleton(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
