import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../projects/application/projects_providers.dart';
import '../application/team_providers.dart';
import 'team_paths.dart';
import 'widgets/team_member_row.dart';

/// The Admin's Team tab (mock 04), shown by the `TeamMembersScreen`
/// placeholder: search, then everyone in the projects they lead.
class TeamBody extends ConsumerStatefulWidget {
  const TeamBody({super.key});

  @override
  ConsumerState<TeamBody> createState() => _TeamBodyState();
}

class _TeamBodyState extends ConsumerState<TeamBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(teamProvider);
    return team.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(
        message: "We couldn't load your team.",
        onRetry: () => ref.invalidate(myProjectsProvider),
      ),
      data: (all) => all.isEmpty
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No team members yet',
              message:
                  'People you add to your projects show up here, with their '
                  'workload and leave.',
            )
          : _List(
              members: filterTeam(all, _query),
              onQuery: (q) => setState(() => _query = q),
            ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.members, required this.onQuery});

  final List<TeamMember> members;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextField(
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search team members…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            if (members.isEmpty)
              const EmptyState(
                icon: Icons.search_off,
                title: 'No matches',
                message: 'Try another name or email.',
              )
            else
              for (final (i, m) in members.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                TeamMemberRow(
                  member: m,
                  onOpen: () => context.push(memberProfilePath(m.user.uid)),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
