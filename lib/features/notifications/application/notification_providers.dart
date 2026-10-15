import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Unread in-app notifications for the signed-in user, shown as the dot on
/// the app bar bell. Stubbed at 0 until Phase 8 adds the `notifications`
/// collection (its Firestore rules still deny all access).
final unreadNotificationCountProvider = Provider<int>((ref) => 0);
