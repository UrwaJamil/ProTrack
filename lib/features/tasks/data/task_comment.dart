import 'package:cloud_firestore/cloud_firestore.dart';

const commentMaxLength = 2000;

/// `projects/{pid}/tasks/{tid}/comments/{cid}` (CLAUDE.md decision 5).
class TaskComment {
  const TaskComment({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.editedAt,
  });

  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;

  /// Set when the author edited the text.
  final DateTime? editedAt;

  bool get isEdited => editedAt != null;

  factory TaskComment.fromMap(String id, Map<String, dynamic> map) =>
      TaskComment(
        id: id,
        authorId: map['authorId'] as String? ?? '',
        text: map['text'] as String? ?? '',
        // Null while a just-written server timestamp is pending.
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        editedAt: (map['editedAt'] as Timestamp?)?.toDate(),
      );

  /// The stored shape, with resolved dates (the repository writes server
  /// timestamps instead).
  Map<String, dynamic> toMap() => {
    'authorId': authorId,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
    if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
  };
}
