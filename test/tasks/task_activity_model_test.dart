import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/core/utils/time_format.dart';
import 'package:team_project_manager/features/tasks/data/help_note.dart';
import 'package:team_project_manager/features/tasks/data/task_comment.dart';
import 'package:team_project_manager/features/tasks/data/task_history_entry.dart';
import 'package:team_project_manager/features/tasks/presentation/widgets/history_tile.dart';

void main() {
  group('TaskComment', () {
    test('round-trips through toMap / fromMap', () {
      final c = TaskComment(
        id: 'c1',
        authorId: 'u1',
        text: 'Looks good',
        createdAt: DateTime(2026, 10, 1, 9),
        editedAt: DateTime(2026, 10, 1, 10),
      );
      final back = TaskComment.fromMap('c1', c.toMap());
      expect(back.authorId, 'u1');
      expect(back.text, 'Looks good');
      expect(back.createdAt, c.createdAt);
      expect(back.editedAt, c.editedAt);
      expect(back.isEdited, isTrue);
    });

    test('a pending server timestamp does not crash', () {
      final c = TaskComment.fromMap('c1', {'authorId': 'u1', 'text': 'x'});
      expect(c.isEdited, isFalse);
    });
  });

  group('TaskHistoryEntry', () {
    test('round-trips, with stored action values', () {
      final e = TaskHistoryEntry(
        id: 'h1',
        who: 'u1',
        action: HistoryAction.helpRequested,
        from: 'in_progress',
        to: 'u2',
        at: DateTime(2026, 10, 2),
      );
      final map = e.toMap();
      expect(map['action'], 'help_requested');
      final back = TaskHistoryEntry.fromMap('h1', map);
      expect(back.action, HistoryAction.helpRequested);
      expect(back.from, 'in_progress');
      expect(back.to, 'u2');
      expect(back.at, e.at);
    });

    test('rejects unknown actions', () {
      expect(
        () => TaskHistoryEntry.fromMap('h', {
          'who': 'u',
          'action': 'hacked',
          'at': Timestamp.now(),
        }),
        throwsFormatException,
      );
    });

    test('describeHistory', () {
      String name(String uid) => {'u2': 'Zain Ahmed'}[uid] ?? '?';
      TaskHistoryEntry e(HistoryAction a, {String? to}) => TaskHistoryEntry(
        id: 'h',
        who: 'u1',
        action: a,
        to: to,
        at: DateTime(2026),
      );
      expect(
        describeHistory(e(HistoryAction.helpRequested, to: 'u2'), name),
        'requested help from Zain Ahmed',
      );
      expect(
        describeHistory(e(HistoryAction.helpRequested), name),
        'requested help',
      );
      expect(
        describeHistory(e(HistoryAction.helpAccepted, to: 'u2'), name),
        "accepted Zain Ahmed's help request",
      );
      expect(
        describeHistory(e(HistoryAction.statusChanged, to: 'blocked'), name),
        'changed status to Blocked',
      );
    });
  });

  group('HelpNote', () {
    test('round-trips and drops absent fields', () {
      const note = HelpNote(text: 'Stuck on rules', taggedUserId: 'u2');
      expect(note.toMap(), {'text': 'Stuck on rules', 'taggedUserId': 'u2'});
      final back = HelpNote.fromField(note.toMap())!;
      expect(back.text, 'Stuck on rules');
      expect(back.taggedUserId, 'u2');
      expect(back.taggedSkill, isNull);
    });

    test('requestId round-trips; withRequestId keeps the rest', () {
      const note = HelpNote(text: 'Stuck', taggedUserId: 'u2');
      final withId = note.withRequestId('h9');
      expect(withId.toMap(), {
        'text': 'Stuck',
        'taggedUserId': 'u2',
        'requestId': 'h9',
      });
      expect(HelpNote.fromField(withId.toMap())!.requestId, 'h9');
    });

    test('missing or malformed fields read as no note', () {
      expect(HelpNote.fromField(null), isNull);
      expect(HelpNote.fromField('text'), isNull);
      expect(HelpNote.fromField({'text': '  '}), isNull);
    });
  });

  group('formatDayTime', () {
    final now = DateTime(2026, 11, 9, 10);
    test('today / yesterday / older', () {
      expect(
        formatDayTime(DateTime(2026, 11, 9, 14, 15), now: now),
        'Today, 02:15 PM',
      );
      expect(
        formatDayTime(DateTime(2026, 11, 8, 0, 5), now: now),
        'Yesterday, 12:05 AM',
      );
      expect(
        formatDayTime(DateTime(2026, 10, 12, 10), now: now),
        'Oct 12, 2026, 10:00 AM',
      );
    });
  });
}
