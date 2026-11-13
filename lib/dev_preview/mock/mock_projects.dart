import '../../features/auth/data/app_user.dart';
import '../../features/projects/data/project.dart';
import 'mock_people.dart';

/// "Today" in the preview: the date selected in the Calendar mock, so
/// overdue and days-left labels stay stable.
final mockToday = DateTime(2026, 11, 9, 10);

/// Projects named in `design/screens/` (Analytics "Project progress",
/// notifications). Ids start with the characters their short id shows,
/// e.g. Mobile App v2 is PRJ-A182.
abstract final class MockProjects {
  static const mobileApp = 'a182mobileapp';
  static const cloudMigration = 'c7m2cloud';
  static const designSystem = 'd5s9design';
  static const phoenix = 'p8x4phoenix';
  static const legacy = 'l3g0legacy';

  static const _l = UserRole.leader;
  static const _m = UserRole.member;

  static final all = [
    _project(
      mobileApp,
      'Mobile App v2',
      'Redesign of the ProTrack mobile app: login, navigation and task '
          'flows for Android and web.',
      start: DateTime(2026, 9, 1),
      deadline: DateTime(2026, 12, 15),
      members: {
        MockPeople.tariq: _l,
        MockPeople.ayesha: _m,
        MockPeople.hamza: _m,
        MockPeople.sara: _m,
        MockPeople.bilal: _m,
        MockPeople.zain: _m,
      },
    ),
    _project(
      cloudMigration,
      'Cloud Migration',
      'Move the backend to Firebase: schema review, security rules and '
          'Cloud Functions.',
      start: DateTime(2026, 9, 15),
      deadline: DateTime(2026, 12, 20),
      members: {
        MockPeople.tariq: _l,
        MockPeople.sara: _m,
        MockPeople.bilal: _m,
        MockPeople.zain: _m,
      },
    ),
    // Deadline passed with work left: shows as Overdue.
    _project(
      designSystem,
      'Design System',
      'Shared tokens, typography and icons for every ProTrack surface.',
      start: DateTime(2026, 8, 1),
      deadline: DateTime(2026, 11, 5),
      members: {
        MockPeople.tariq: _l,
        MockPeople.ayesha: _m,
        MockPeople.hamza: _m,
      },
    ),
    // Led by Hamza with Tariq as a Member: the Admin's "My Projects" and
    // the read-only project view.
    _project(
      phoenix,
      'Project Phoenix',
      'Discovery and kickoff for the next-generation planning tool.',
      start: DateTime(2026, 10, 20),
      deadline: DateTime(2027, 1, 31),
      createdBy: MockPeople.hamza,
      members: {
        MockPeople.hamza: _l,
        MockPeople.tariq: _m,
        MockPeople.ayesha: _m,
      },
    ),
    _project(
      legacy,
      'Legacy Portal',
      'Retired customer portal, kept for reference.',
      start: DateTime(2026, 3, 1),
      deadline: DateTime(2026, 6, 30),
      status: ProjectStatus.archived,
      members: {MockPeople.tariq: _l, MockPeople.bilal: _m},
    ),
  ];

  static Project _project(
    String id,
    String name,
    String description, {
    required DateTime start,
    required DateTime deadline,
    required Map<String, UserRole> members,
    String createdBy = MockPeople.tariq,
    ProjectStatus status = ProjectStatus.active,
  }) => Project(
    id: id,
    name: name,
    description: description,
    startDate: start,
    deadline: deadline,
    status: status,
    createdBy: createdBy,
    members: members,
    createdAt: start,
  );
}
