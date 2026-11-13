import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/app_user.dart';
import '../../leave/presentation/widgets/leave_badges.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/data/project.dart';
import '../../tasks/presentation/task_paths.dart';
import '../../tasks/presentation/widgets/task_status_badge.dart';
import '../application/team_providers.dart';
import 'widgets/add_to_project_sheet.dart';

/// A team member's profile for the Admin (`/leader/team/:uid`, mock 04):
/// avatar, name, email, role, On Leave, read-only skills, their tasks in
/// projects the Admin can read, and "Add to project".
class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userProfilesProvider(profilesKey([uid])));
    final Widget body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(
        message: "We couldn't load this profile.",
        onRetry: () => ref.invalidate(userProfilesProvider(profilesKey([uid]))),
      ),
      data: (profiles) => switch (profiles[uid]) {
        final user? => _Profile(user: user),
        null => const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile not found',
          message: 'This account may have been removed.',
        ),
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Member Profile')),
      body: body,
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUidProvider) ?? '';
    final team = ref.watch(teamProvider).value ?? const [];
    final role =
        team.where((m) => m.user.uid == user.uid).firstOrNull?.role ??
        user.defaultRole;
    final addable = projectsToAddTo(
      me,
      user.uid,
      ref.watch(myProjectsProvider).value ?? const [],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Center(
              child: UserAvatar(uid: user.uid, name: user.name, size: 72),
            ),
            const SizedBox(height: 12),
            Text(
              user.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                LabelPill(label: role.label),
                OnLeaveIndicator(uid: user.uid),
              ],
            ),
            const SizedBox(height: 24),
            _Skills(skills: user.skillTags),
            const SizedBox(height: 24),
            _CurrentTasks(uid: user.uid),
            const SizedBox(height: 24),
            _AddButton(user: user, projects: addable),
          ],
        ),
      ),
    );
  }
}

class _Skills extends StatelessWidget {
  const _Skills({required this.skills});

  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skills',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (skills.isEmpty)
          Text(
            'No skills listed yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in skills) LabelPill(label: s)],
          ),
      ],
    );
  }
}

class _CurrentTasks extends ConsumerWidget {
  const _CurrentTasks({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final async = ref.watch(memberTasksProvider(uid));
    final tasks = async.value;
    final active = tasks?.where((t) => !t.task.isCompleted).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Current tasks',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (tasks != null)
              Text(
                '$active active',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (async.hasError)
          Text(
            "We couldn't load their tasks.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (tasks == null)
          const Center(child: CircularProgressIndicator())
        else if (tasks.isEmpty)
          Text(
            'No tasks in your projects.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          )
        else
          for (final t in tasks)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  t.task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(t.project.name),
                trailing: TaskStatusBadge(status: t.task.status),
                onTap: () => context.push(
                  taskDetailPath(t.project.id, t.task.id, adminView: true),
                ),
              ),
            ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.user, required this.projects});

  final AppUser user;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: projects.isEmpty
                ? null
                : () => showAddToProjectSheet(
                    context,
                    uid: user.uid,
                    name: user.name,
                    projects: projects,
                  ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add to project'),
          ),
        ),
        if (projects.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Already in every active project you lead.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
