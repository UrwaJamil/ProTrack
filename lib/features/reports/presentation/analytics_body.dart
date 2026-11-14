import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/presentation/project_ui_actions.dart';
import '../../tasks/application/tasks_providers.dart';
import '../application/analytics_providers.dart';
import 'widgets/project_progress_card.dart';
import 'widgets/stat_tile.dart';
import 'widgets/tasks_by_status_card.dart';

/// The Admin's Analytics (mock 03), shown by the `AnalyticsScreen`
/// placeholder: four stat tiles, "Tasks by status" and "Project
/// progress", over the active projects the user leads.
class AnalyticsBody extends ConsumerWidget {
  const AnalyticsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(ledProjectsProvider).value?.isEmpty ?? false) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'No projects you lead',
        message: 'Analytics covers the active projects you lead.',
      );
    }
    return ref
        .watch(analyticsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorState(
            message: "We couldn't load your analytics.",
            onRetry: () => ref
              ..invalidate(myProjectsProvider)
              ..invalidate(projectTasksProvider),
          ),
          data: (a) => _Content(analytics: a),
        );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.analytics});

  final TeamAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = analytics;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            StatGrid(
              tiles: [
                StatTile(
                  label: 'Projects',
                  value: '${a.projectCount}',
                  icon: Icons.folder_outlined,
                ),
                StatTile(
                  label: 'Completed %',
                  value: '${a.completedPercent}%',
                  icon: Icons.check_circle_outline,
                  iconColor: theme.appColors.success,
                ),
                StatTile(
                  label: 'Overdue',
                  value: '${a.overdue}',
                  icon: Icons.schedule,
                  valueColor: theme.colorScheme.error,
                  iconColor: theme.colorScheme.error,
                ),
                StatTile(
                  label: 'Blocked',
                  value: '${a.blocked}',
                  icon: Icons.error_outline,
                  valueColor: theme.appColors.warning,
                  iconColor: theme.appColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TasksByStatusCard(counts: a.countsByStatus),
            const SizedBox(height: 16),
            ProjectProgressCard(
              items: a.projectProgress,
              onOpen: (id) =>
                  context.push(projectDetailPath(id, adminView: true)),
            ),
          ],
        ),
      ),
    );
  }
}
