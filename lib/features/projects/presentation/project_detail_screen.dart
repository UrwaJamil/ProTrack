import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../application/project_filters.dart';
import '../application/project_permissions.dart';
import '../application/projects_providers.dart';
import '../data/project.dart';
import 'widgets/assign_member_search.dart';
import 'widgets/project_status_badge.dart';
import 'widgets/project_summary_card.dart';
import 'widgets/team_members_section.dart';

/// One project, for both dashboards (`/leader/projects/:id` and
/// `/member/projects/:id`). What's editable comes from the project's own
/// `members` map, not the route: its Admins get Edit, "+ Add", member
/// removal and the email search; everyone else gets the read-only view.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final async = ref.watch(projectProvider(projectId));
    final project = async.value;
    final permissions = project == null
        ? null
        : ProjectPermissions(project, uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
        actions: [
          if (permissions?.canEditDetails ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context)
                      .appBarTheme
                      .foregroundColor,
                ),
                onPressed: () =>
                    context.push('/leader/projects/$projectId/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Includes losing access (removed from the project): the rules
        // then refuse the read.
        error: (_, _) => ErrorState(
          message:
              "We couldn't load this project. You may no longer have "
              'access to it.',
          onRetry: () => ref.invalidate(projectProvider(projectId)),
        ),
        data: (project) => project == null
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'Project not found',
                message: 'It may have been deleted.',
              )
            : _Details(project: project, permissions: permissions!),
      ),
    );
  }
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.project, required this.permissions});

  final Project project;
  final ProjectPermissions permissions;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final permissions = widget.permissions;
    final today = ref.watch(todayProvider);
    final progress = ref.watch(projectProgressProvider(project.id));
    final overdue = isOverdue(project, today: today, progress: progress);
    final manage = permissions.canManageMembers;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                ProjectStatusBadge(
                  kind: project.isArchived
                      ? ProjectBadgeKind.archived
                      : overdue
                      ? ProjectBadgeKind.overdue
                      : ProjectBadgeKind.active,
                ),
                const SizedBox(width: 8),
                LabelPill(label: project.shortId),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              project.name,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ProjectSummaryCard(
              project: project,
              progress: progress,
              today: today,
            ),
            const SizedBox(height: 24),
            TeamMembersSection(
              project: project,
              permissions: permissions,
              onAdd: manage ? _searchFocus.requestFocus : null,
            ),
            if (manage) ...[
              const SizedBox(height: 24),
              AssignMemberSearch(project: project, focusNode: _searchFocus),
            ],
          ],
        ),
      ),
    );
  }
}
