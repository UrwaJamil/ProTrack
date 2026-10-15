import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/projects/data/project.dart';

/// A project created by `admin`, with `member1` as a Member, unless told
/// otherwise.
Project testProject({
  String id = 'abcd1234',
  String name = 'Mobile App Redesign',
  String createdBy = 'admin',
  Map<String, UserRole>? members,
  ProjectStatus status = ProjectStatus.active,
  DateTime? startDate,
  DateTime? deadline,
  DateTime? createdAt,
}) => Project(
  id: id,
  name: name,
  description: 'Refresh the mobile experience.',
  startDate: startDate ?? DateTime(2026, 10, 1),
  deadline: deadline ?? DateTime(2026, 11, 28),
  status: status,
  createdBy: createdBy,
  members: members ?? {createdBy: UserRole.leader, 'member1': UserRole.member},
  createdAt: createdAt ?? DateTime(2026, 10, 1),
);
