import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/app_user.dart';
import 'mock/mock_people.dart';

/// Signs the preview in as the mock "me" for [role] (Tariq Khan for
/// Admin, Ayesha Noor for Member), through the real [AuthController] so
/// screens see an ordinary authenticated session. No-op if already there.
Future<void> switchPreviewRole({
  required AuthState current,
  required AuthController controller,
  required UserRole role,
}) async {
  if (current.status == AuthStatus.authenticated &&
      current.user?.uid == MockPeople.meFor(role)) {
    return;
  }
  await controller.login(
    email: MockPeople.emailOf(MockPeople.meFor(role)),
    password: 'preview',
  );
}
