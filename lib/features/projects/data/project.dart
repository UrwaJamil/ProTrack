import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/app_user.dart';

enum ProjectStatus {
  active('active'),
  archived('archived');

  const ProjectStatus(this.value);

  /// The exact string stored in `projects/{pid}.status`.
  final String value;

  static ProjectStatus fromValue(String? value) =>
      value == 'archived' ? ProjectStatus.archived : ProjectStatus.active;
}

/// `projects/{pid}`. A member's role inside the project lives in [members]
/// (`leader` = Admin, `member` = Member — CLAUDE.md decision 1); the stored
/// `memberIds` array always equals the keys of [members] (Firestore rules
/// enforce it) and exists only for `array-contains` queries.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.deadline,
    required this.status,
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;

  /// Calendar dates (local midnight); only the day matters.
  final DateTime startDate;
  final DateTime deadline;

  final ProjectStatus status;
  final String createdBy;
  final Map<String, UserRole> members;
  final DateTime createdAt;

  /// Display id derived from the doc id ("PRJ-7F3K"), so no counter doc is
  /// needed. Not unique in theory, but plenty to tell projects apart.
  String get shortId {
    final head = id.length >= 4 ? id.substring(0, 4) : id;
    return 'PRJ-${head.toUpperCase()}';
  }

  List<String> get memberIds => members.keys.toList();

  bool get isArchived => status == ProjectStatus.archived;

  UserRole? roleOf(String uid) => members[uid];

  factory Project.fromMap(String id, Map<String, dynamic> map) {
    final rawMembers = map['members'] as Map<String, dynamic>? ?? const {};
    return Project(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      startDate: _date(map['startDate']),
      deadline: _date(map['deadline']),
      status: ProjectStatus.fromValue(map['status'] as String?),
      createdBy: map['createdBy'] as String? ?? '',
      members: {
        // Unknown roles are skipped rather than coerced (rules prevent them).
        for (final entry in rawMembers.entries)
          if (entry.value == 'leader' || entry.value == 'member')
            entry.key: UserRole.fromValue(entry.value as String),
      },
      // Null while a just-created doc's server timestamp is pending.
      createdAt: _date(map['createdAt'], fallback: DateTime.now()),
    );
  }

  /// The fields written on create (timestamps are added by the repository).
  Map<String, dynamic> toCreateMap() => {
    'name': name,
    'description': description,
    'startDate': Timestamp.fromDate(startDate),
    'deadline': Timestamp.fromDate(deadline),
    'status': status.value,
    'createdBy': createdBy,
    'members': membersToMap(members),
    'memberIds': memberIds,
  };

  static Map<String, String> membersToMap(Map<String, UserRole> members) => {
    for (final entry in members.entries) entry.key: entry.value.value,
  };

  static DateTime _date(Object? value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// A new `members` map plus the matching `memberIds`, always derived
/// together so the two can never drift apart.
typedef MemberChange = ({Map<String, String> members, List<String> memberIds});

/// Adds [uid] to [project] as a Member. Throws [ArgumentError] if they're
/// already in it.
MemberChange addMemberChange(Project project, String uid) {
  if (project.members.containsKey(uid)) {
    throw ArgumentError.value(uid, 'uid', 'already a member of the project');
  }
  final members = {...project.members, uid: UserRole.member};
  return (
    members: Project.membersToMap(members),
    memberIds: members.keys.toList(),
  );
}

/// Removes Member [uid] from [project]. Admins (`leader`) — the creator in
/// particular — can't be removed; throws [ArgumentError] for them, or if
/// [uid] isn't in the project.
MemberChange removeMemberChange(Project project, String uid) {
  final role = project.members[uid];
  if (role == null) {
    throw ArgumentError.value(uid, 'uid', 'not a member of the project');
  }
  if (role == UserRole.leader || uid == project.createdBy) {
    throw ArgumentError.value(uid, 'uid', 'project Admins cannot be removed');
  }
  final members = {...project.members}..remove(uid);
  return (
    members: Project.membersToMap(members),
    memberIds: members.keys.toList(),
  );
}
