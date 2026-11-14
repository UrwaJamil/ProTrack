import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leave/application/leave_providers.dart';
import '../../projects/application/projects_providers.dart';
import '../data/help_note.dart';
import '../data/task_activity_repository.dart';
import '../data/task_comment.dart';
import '../data/task_history_entry.dart';
import 'helper_ranking.dart';
import 'tasks_providers.dart';

/// History page size; "Load more" adds another page.
const historyPageSize = 20;

/// A task's comments, oldest first.
final taskCommentsProvider = StreamProvider.family<List<TaskComment>, TaskKey>(
  (ref, key) => ref
      .watch(taskActivityRepositoryProvider)
      .watchComments(key.projectId, key.taskId),
);

typedef HistoryKey = ({String projectId, String taskId, int limit});

/// A task's newest [HistoryKey.limit] history entries.
final taskHistoryProvider =
    StreamProvider.family<List<TaskHistoryEntry>, HistoryKey>(
      (ref, key) => ref
          .watch(taskActivityRepositoryProvider)
          .watchHistory(key.projectId, key.taskId, limit: key.limit),
    );

/// The task's help note, if any.
final taskHelpNoteProvider = StreamProvider.family<HelpNote?, TaskKey>(
  (ref, key) => ref
      .watch(taskActivityRepositoryProvider)
      .watchHelpNote(key.projectId, key.taskId),
);

/// Need Help's "Who can help?" list ([rankHelpers]) for this task's
/// project, without the signed-in user and anyone on approved leave
/// today (Phase 6).
final helperCandidatesProvider =
    Provider.family<AsyncValue<List<HelperCandidate>>, TaskKey>((ref, key) {
      final uid = ref.watch(currentUidProvider) ?? '';
      final project = ref.watch(projectProvider(key.projectId));
      final tasks = ref.watch(projectTasksProvider(key.projectId));
      final memberIds = project.value?.memberIds ?? const <String>[];
      final profiles = ref.watch(userProfilesProvider(profilesKey(memberIds)));
      final onLeave = ref.watch(onLeaveTodayProvider);

      for (final async in [project, tasks, profiles]) {
        if (async.hasError) return AsyncError(async.error!, async.stackTrace!);
      }
      final profileMap = profiles.value;
      final taskList = tasks.value;
      if (!project.hasValue || profileMap == null || taskList == null) {
        return const AsyncLoading();
      }
      return AsyncData(
        rankHelpers(
          memberIds: memberIds,
          profiles: profileMap,
          projectTasks: taskList,
          requesterUid: uid,
          unavailable: onLeave,
        ),
      );
    });

typedef HelpRequestKey = ({String projectId, String taskId, String requestId});

/// Whether a help request was already accepted by its helper.
final helpAcceptedProvider = StreamProvider.family<bool, HelpRequestKey>(
  (ref, key) => ref
      .watch(taskActivityRepositoryProvider)
      .watchAccepted(key.projectId, key.taskId, key.requestId),
);
