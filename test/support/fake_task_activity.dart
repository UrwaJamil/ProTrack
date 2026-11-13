import 'package:team_project_manager/dev_preview/fakes/preview_task_activity_repository.dart';
import 'package:team_project_manager/features/tasks/data/help_note.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

/// The preview's in-memory activity repository plus write-failure
/// injection and a call log.
class FakeTaskActivityRepository extends PreviewTaskActivityRepository {
  FakeTaskActivityRepository(
    super.tasks, {
    super.comments,
    super.history,
    super.helpNotes,
  });

  final calls = <String>[];

  /// Makes writes throw.
  Object? writeError;

  void _check(String call) {
    calls.add(call);
    if (writeError != null) throw writeError!;
  }

  @override
  Future<void> addComment(
    String projectId,
    String taskId, {
    required String authorId,
    required String text,
  }) async {
    _check('addComment');
    await super.addComment(projectId, taskId, authorId: authorId, text: text);
  }

  @override
  Future<void> editComment(
    String projectId,
    String taskId,
    String commentId,
    String text,
  ) async {
    _check('editComment');
    await super.editComment(projectId, taskId, commentId, text);
  }

  @override
  Future<void> deleteComment(
    String projectId,
    String taskId,
    String commentId,
  ) async {
    _check('deleteComment');
    await super.deleteComment(projectId, taskId, commentId);
  }

  @override
  Future<void> requestHelp(
    String projectId,
    String taskId, {
    required String requesterUid,
    required TaskStatus previousStatus,
    required HelpNote note,
  }) async {
    _check('requestHelp');
    await super.requestHelp(
      projectId,
      taskId,
      requesterUid: requesterUid,
      previousStatus: previousStatus,
      note: note,
    );
  }

  @override
  Future<void> acceptHelp(
    String projectId,
    String taskId, {
    required String helperUid,
    required String helperName,
    required HelpNote note,
  }) async {
    _check('acceptHelp');
    await super.acceptHelp(
      projectId,
      taskId,
      helperUid: helperUid,
      helperName: helperName,
      note: note,
    );
  }
}
