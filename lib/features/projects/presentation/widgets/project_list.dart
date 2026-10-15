import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/pill_toggle.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/data/app_user.dart';
import '../../application/project_filters.dart';
import '../../application/project_permissions.dart';
import '../../application/projects_providers.dart';
import '../../data/project.dart';
import '../project_ui_actions.dart';
import 'project_card.dart';
import 'project_filter_chips.dart';
import 'projects_header.dart';

/// The loaded overview: header, (Admin) scope toggle, filter chips with
/// live counts and the project cards — or the empty state.
class ProjectList extends ConsumerWidget {
  const ProjectList({
    super.key,
    required this.projects,
    required this.adminView,
  });

  final List<Project> projects;
  final bool adminView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (projects.isEmpty) return _NoProjects(adminView: adminView);

    final uid = ref.watch(currentUidProvider) ?? '';
    final today = ref.watch(todayProvider);
    final filter = ref.watch(projectFilterProvider);
    final scope = ref.watch(projectScopeProvider);
    int progressOf(Project p) => ref.watch(projectProgressProvider(p.id));

    final scoped = adminView ? applyScope(projects, scope, uid) : projects;
    final counts = filterCounts(scoped, today: today, progressOf: progressOf);
    final visible = scoped
        .where(
          (p) => matchesFilter(p, filter, today: today, progressOf: progressOf),
        )
        .toList();
    final profiles =
        ref
            .watch(
              userProfilesProvider(
                profilesKey(visible.expand((p) => p.memberIds)),
              ),
            )
            .value ??
        const {};

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, adminView ? 104 : 24),
          children: [
            ProjectsHeader(adminView: adminView),
            const SizedBox(height: 16),
            if (adminView) ...[
              PillToggle<ProjectScope>(
                value: scope,
                onChanged: ref.read(projectScopeProvider.notifier).select,
                segments: const [
                  PillSegment(value: ProjectScope.all, label: 'All Projects'),
                  PillSegment(value: ProjectScope.mine, label: 'My Projects'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            ProjectFilterChips(
              selected: filter,
              counts: counts,
              onSelected: ref.read(projectFilterProvider.notifier).select,
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              const EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'Nothing here',
                message: 'No projects match this filter.',
              ),
            for (final project in visible) ...[
              _ProjectListItem(
                project: project,
                adminView: adminView,
                uid: uid,
                today: today,
                profiles: profiles,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectListItem extends ConsumerWidget {
  const _ProjectListItem({
    required this.project,
    required this.adminView,
    required this.uid,
    required this.today,
    required this.profiles,
  });

  final Project project;
  final bool adminView;
  final String uid;
  final DateTime today;
  final Map<String, AppUser> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(projectProgressProvider(project.id));
    return ProjectCard(
      project: project,
      progress: progress,
      overdue: isOverdue(project, today: today, progress: progress),
      people: [
        for (final id in creatorFirst(project))
          (uid: id, name: profiles[id]?.name ?? ''),
      ],
      canManage: ProjectPermissions(project, uid).isLeader,
      onOpen: () =>
          context.push(projectDetailPath(project.id, adminView: adminView)),
      onEdit: () => context.push('/leader/projects/${project.id}/edit'),
      onToggleArchive: () => toggleProjectArchived(context, ref, project),
    );
  }
}

/// Member ids with the project creator first.
List<String> creatorFirst(Project p) => [
  if (p.members.containsKey(p.createdBy)) p.createdBy,
  ...p.memberIds.where((id) => id != p.createdBy),
];

class _NoProjects extends StatelessWidget {
  const _NoProjects({required this.adminView});

  final bool adminView;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProjectsHeader(adminView: adminView),
        const SizedBox(height: 48),
        EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No projects yet',
          message: adminView
              ? 'Create a project to plan tasks, deadlines and your team.'
              : 'Projects appear here once an Admin adds you to one.',
          action: adminView
              ? OutlinedButton.icon(
                  onPressed: () => context.push('/leader/projects/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Project'),
                )
              : null,
        ),
      ],
    );
  }
}
