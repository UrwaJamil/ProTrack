import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/tasks/data/task_activity_repository.dart';

void main() {
  Map<String, dynamic> build({String name = 'Sam', String title = 'Fix it'}) =>
      helpRequestedNotification(
        helperUid: 'h1',
        requesterUid: 'r1',
        requesterName: name,
        taskTitle: title,
        projectId: 'p1',
        taskId: 't1',
      );

  test('addressed to the helper, sent by the requester', () {
    expect(build(), {
      'userId': 'h1',
      'senderId': 'r1',
      'type': 'help_requested',
      'projectId': 'p1',
      'taskId': 't1',
      'message': 'Sam requested your help on Fix it',
      'read': false,
    });
    expect(helpRequestedNotificationId('req1'), 'help_requested_req1');
  });

  test('message stays within the rules\' 200-character limit', () {
    final msg = build(name: 'N' * 500, title: 'T' * 100)['message'] as String;
    expect(msg.length, lessThanOrEqualTo(200));
    expect(msg, startsWith('${'N' * 59}… requested your help on '));
  });
}
