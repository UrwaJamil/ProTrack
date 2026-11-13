import '../../features/auth/data/app_user.dart';

/// People from `design/screens/`. Tariq Khan is the Admin "me" (Admin
/// Profile mock) and Ayesha Noor the Member "me" (Member Profile mock).
abstract final class MockPeople {
  static const tariq = 'tariq';
  static const ayesha = 'ayesha';
  static const hamza = 'hamza';
  static const sara = 'sara';
  static const bilal = 'bilal';
  static const zain = 'zain';

  /// The preview's signed-in user for each dashboard.
  static String meFor(UserRole role) => switch (role) {
    UserRole.leader => tariq,
    UserRole.member => ayesha,
  };

  static final all = [
    _user(tariq, 'Tariq Khan', UserRole.leader, ['Architecture', 'Planning']),
    _user(ayesha, 'Ayesha Noor', UserRole.member, [
      'Flutter',
      'Firebase',
      'UI Design',
      'REST APIs',
    ]),
    _user(hamza, 'Hamza Farooq', UserRole.leader, ['Architecture', 'Backend']),
    _user(sara, 'Sara Malik', UserRole.member, ['Firebase', 'Cloud Functions']),
    _user(bilal, 'Bilal Siddiqui', UserRole.member, ['Android', 'QA']),
    _user(zain, 'Zain Ahmed', UserRole.member, ['Firebase', 'Security Rules']),
  ];

  static String emailOf(String uid) =>
      all.firstWhere((u) => u.uid == uid).email;

  static AppUser _user(
    String uid,
    String name,
    UserRole role,
    List<String> skills,
  ) => AppUser(
    uid: uid,
    name: name,
    email: '${name.toLowerCase().replaceAll(' ', '.')}@protrack.io',
    defaultRole: role,
    skillTags: skills,
    createdAt: DateTime(2026, 1, 10),
  );
}
