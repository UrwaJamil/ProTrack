import '../../features/tasks/data/task.dart';
import '../../features/tasks/data/task_priority.dart';
import '../../features/tasks/data/task_status.dart';
import 'mock_people.dart';
import 'mock_projects.dart';

/// Tasks from `design/screens/` (Task Details, Member Profile, Calendar,
/// notifications), covering every status, priority and an overdue one.
abstract final class MockTasks {
  static const designLogin = '7f3kdesignlogin';
  static const firestoreRules = 'fsr6rules';

  static final all = [
    // ---- Mobile App v2
    _task(
      MockProjects.mobileApp,
      designLogin,
      'Design login flow',
      'Login, register and biometric prompt screens for Android and web, '
          'matching the design tokens (#27374D primary).',
      assignedTo: [MockPeople.ayesha],
      priority: TaskPriority.high,
      status: TaskStatus.inProgress,
      deadline: DateTime(2026, 11, 14),
      subtasks: const [
        Subtask(title: 'Wireframes', done: true),
        Subtask(title: 'Design password reset', done: true),
        Subtask(title: 'Biometric prompt variants'),
        Subtask(title: 'Dark mode pass'),
      ],
    ),
    _task(
      MockProjects.mobileApp,
      'n4vbnavbar',
      'Fix navigation bar bug',
      'The bottom nav loses the selected tab after returning from a '
          'pushed screen.',
      assignedTo: [MockPeople.ayesha],
      status: TaskStatus.completed,
      deadline: DateTime(2026, 11, 7),
    ),
    _task(
      MockProjects.mobileApp,
      'pw9rreset',
      'Password reset wireframes',
      'Forgot-password and reset-link landing screens.',
      assignedTo: [MockPeople.ayesha],
      priority: TaskPriority.low,
      status: TaskStatus.onHold,
      deadline: DateTime(2026, 11, 20),
    ),
    _task(
      MockProjects.mobileApp,
      'api2integration',
      'API integration specs',
      'Document the REST endpoints the mobile app calls.',
      assignedTo: [MockPeople.zain, MockPeople.sara],
      priority: TaskPriority.high,
      status: TaskStatus.blocked,
      deadline: DateTime(2026, 11, 12),
    ),
    _task(
      MockProjects.mobileApp,
      'onb5onboarding',
      'Onboarding carousel',
      'Three intro slides shown on first launch.',
      assignedTo: [MockPeople.bilal],
      deadline: DateTime(2026, 11, 25),
    ),
    // ---- Cloud Migration
    _task(
      MockProjects.cloudMigration,
      'rdb1schema',
      'Review database schema',
      'Check the Firestore data model against the query list.',
      assignedTo: [MockPeople.sara],
      status: TaskStatus.completed,
      deadline: DateTime(2026, 11, 9),
    ),
    _task(
      MockProjects.cloudMigration,
      firestoreRules,
      'Set up Firestore security rules',
      'Rules for projects, tasks and comments, with emulator tests.',
      assignedTo: [MockPeople.zain, MockPeople.bilal],
      priority: TaskPriority.high,
      deadline: DateTime(2026, 11, 6),
    ),
    _task(
      MockProjects.cloudMigration,
      'cfn3functions',
      'Migrate Cloud Functions',
      'Port the notification triggers to 2nd-gen functions.',
      assignedTo: [MockPeople.sara],
      status: TaskStatus.inProgress,
      deadline: DateTime(2026, 11, 22),
      subtasks: const [
        Subtask(title: 'Inventory triggers', done: true),
        Subtask(title: 'Port onCreate handlers'),
      ],
    ),
    // ---- Design System (overdue project)
    _task(
      MockProjects.designSystem,
      'tok8tokens',
      'Color tokens',
      'Light and dark palette as design tokens.',
      assignedTo: [MockPeople.ayesha],
      status: TaskStatus.completed,
      deadline: DateTime(2026, 10, 20),
    ),
    _task(
      MockProjects.designSystem,
      'typ4typescale',
      'Typography scale',
      'Plus Jakarta Sans type ramp.',
      assignedTo: [MockPeople.hamza],
      status: TaskStatus.completed,
      deadline: DateTime(2026, 10, 25),
    ),
    _task(
      MockProjects.designSystem,
      'icn7iconset',
      'Icon set',
      'Outline icon set for navigation and status.',
      assignedTo: [MockPeople.ayesha],
      status: TaskStatus.inProgress,
      deadline: DateTime(2026, 11, 4),
    ),
    // ---- Project Phoenix (Hamza leads)
    _task(
      MockProjects.phoenix,
      'phx1kickoff',
      'Kickoff deck',
      'Goals, scope and timeline for the kickoff meeting.',
      assignedTo: [MockPeople.tariq],
      status: TaskStatus.inProgress,
      deadline: DateTime(2026, 11, 18),
      createdBy: MockPeople.hamza,
    ),
    _task(
      MockProjects.phoenix,
      'phx2research',
      'User research synthesis',
      'Summarise the twelve customer interviews.',
      assignedTo: [MockPeople.ayesha],
      deadline: DateTime(2026, 11, 28),
      createdBy: MockPeople.hamza,
    ),
    // ---- Legacy Portal (archived)
    _task(
      MockProjects.legacy,
      'leg1archive',
      'Archive documentation',
      'Export the wiki to PDF.',
      assignedTo: [MockPeople.bilal],
      status: TaskStatus.completed,
      deadline: DateTime(2026, 6, 20),
    ),
  ];

  static Task _task(
    String projectId,
    String id,
    String title,
    String description, {
    required List<String> assignedTo,
    required DateTime deadline,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    List<Subtask> subtasks = const [],
    String createdBy = MockPeople.tariq,
  }) => Task(
    id: id,
    projectId: projectId,
    title: title,
    description: description,
    assignedTo: assignedTo,
    priority: priority,
    status: status,
    deadline: deadline,
    subtasks: subtasks,
    createdBy: createdBy,
    createdAt: DateTime(2026, 10, 12, 10),
  );
}
