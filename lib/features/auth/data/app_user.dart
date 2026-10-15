import 'package:cloud_firestore/cloud_firestore.dart';

/// The two dashboard roles (`users/{uid}.defaultRole` in Firestore).
///
/// This is only the *default* landing role chosen at registration/login.
/// TODO(phase 2): once projects exist, a project's own `members` map
/// decides the user's role within that specific project, independent of
/// this session-level choice — this enum only picks the initial dashboard.
enum UserRole {
  leader,
  member;

  String get value => switch (this) {
    UserRole.leader => 'leader',
    UserRole.member => 'member',
  };

  String get label => switch (this) {
    UserRole.leader => 'Admin',
    UserRole.member => 'Member',
  };

  /// Strict parse of a stored `defaultRole`: only the exact strings
  /// `"leader"` and `"member"` are valid. Anything else (a missing field, a
  /// legacy pre-rename abbreviation, different casing) is rejected rather than
  /// silently coerced into a role.
  static UserRole fromValue(String? value) => switch (value) {
    'leader' => UserRole.leader,
    'member' => UserRole.member,
    _ => throw FormatException('Unknown defaultRole value: "$value"'),
  };
}

/// `users/{uid}.emailLower`: the search key for "Assign Team Member".
String emailLowerFor(String email) => email.trim().toLowerCase();

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.defaultRole,
    required this.skillTags,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole defaultRole;
  final List<String> skillTags;
  final DateTime createdAt;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      defaultRole: UserRole.fromValue(map['defaultRole'] as String?),
      skillTags: List<String>.from(map['skillTags'] as List? ?? const []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'emailLower': emailLowerFor(email),
    'defaultRole': defaultRole.value,
    'skillTags': skillTags,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  AppUser copyWith({String? name, List<String>? skillTags}) => AppUser(
    uid: uid,
    name: name ?? this.name,
    email: email,
    defaultRole: defaultRole,
    skillTags: skillTags ?? this.skillTags,
    createdAt: createdAt,
  );
}
