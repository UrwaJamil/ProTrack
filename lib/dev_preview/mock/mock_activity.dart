import '../../features/tasks/data/help_note.dart';
import '../../features/tasks/data/task_comment.dart';
import '../../features/tasks/data/task_history_entry.dart';
import '../../features/tasks/data/task_status.dart';
import '../fakes/preview_task_activity_repository.dart';
import 'mock_people.dart';
import 'mock_projects.dart';
import 'mock_tasks.dart';

/// Comments, history and help notes from the Task Comments / Task
/// History / Need Help mocks. History only holds help requests: that's
/// all Phase 4 records (existing flows don't write history yet).
abstract final class MockActivity {
  static const apiSpecs = 'api2integration';

  static final _login = PreviewTaskActivityRepository.key(
    MockProjects.mobileApp,
    MockTasks.designLogin,
  );
  static final _api = PreviewTaskActivityRepository.key(
    MockProjects.mobileApp,
    apiSpecs,
  );

  static DateTime _at(int dayOffset, int hour, int minute) => DateTime(
    mockToday.year,
    mockToday.month,
    mockToday.day + dayOffset,
    hour,
    minute,
  );

  static final comments = <String, List<TaskComment>>{
    _login: [
      TaskComment(
        id: 'c1',
        authorId: MockPeople.tariq,
        text:
            'Please ensure we include Google sign-in and biometric prompt '
            'options in the wireframes.',
        createdAt: _at(0, 8, 15),
      ),
      TaskComment(
        id: 'c2',
        authorId: MockPeople.ayesha,
        text:
            'Uploaded initial Figma variants. Testing biometric prompt flow '
            'on Android 14.',
        createdAt: _at(0, 9, 30),
      ),
      TaskComment(
        id: 'c3',
        authorId: MockPeople.hamza,
        text:
            'Looks clean! Just make sure the primary button matches '
            '#27374D exactly.',
        createdAt: _at(0, 9, 45),
        editedAt: _at(0, 9, 50),
      ),
    ],
  };

  static final history = <String, List<TaskHistoryEntry>>{
    _api: [
      TaskHistoryEntry(
        id: 'h1',
        who: MockPeople.zain,
        action: HistoryAction.helpRequested,
        from: TaskStatus.inProgress.value,
        to: MockPeople.sara,
        at: _at(-1, 16, 30),
      ),
    ],
  };

  static final helpNotes = <String, HelpNote>{
    _api: const HelpNote(
      text:
          'Encountering permission-denied errors on recursive collections '
          'for multi-tenant rules during unit tests.',
      taggedUserId: MockPeople.sara,
      requestId: 'h1',
    ),
  };
}
