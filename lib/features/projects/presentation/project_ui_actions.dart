import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project.dart';
import '../data/project_repository.dart';

/// Archives an active project or restores an archived one, confirming
/// with a snackbar (or reporting the failure). Returns whether it worked.
Future<bool> toggleProjectArchived(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final archiving = !project.isArchived;
  try {
    await ref
        .read(projectRepositoryProvider)
        .setStatus(
          project.id,
          archiving ? ProjectStatus.archived : ProjectStatus.active,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archiving
              ? '"${project.name}" archived'
              : '"${project.name}" restored',
        ),
      ),
    );
    return true;
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archiving
              ? "Couldn't archive the project. Please try again."
              : "Couldn't restore the project. Please try again.",
        ),
      ),
    );
    return false;
  }
}

/// Where a project's detail screen lives for this dashboard. The screen
/// itself decides read-only vs editable from the project's `members` map.
String projectDetailPath(String projectId, {required bool adminView}) =>
    adminView ? '/leader/projects/$projectId' : '/member/projects/$projectId';
