import 'package:team_project_manager/features/auth/data/app_user.dart';

import 'fake_auth.dart';

/// Profiles for the uids the project/task fixtures use.
FakeUserRepository testUsers() {
  final users = FakeUserRepository();
  for (final (id, name) in [
    ('admin', 'Ada Admin'),
    ('admin2', 'Abe Admin'),
    ('member1', 'Mo Member'),
    ('member2', 'Mia Member'),
  ]) {
    users.docs[id] = AppUser(
      uid: id,
      name: name,
      email: '$id@example.com',
      defaultRole: UserRole.member,
      skillTags: const [],
      createdAt: DateTime(2026),
    ).toMap();
  }
  return users;
}
