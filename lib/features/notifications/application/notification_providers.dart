import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_center_providers.dart';

/// Unread in-app notifications for the signed-in user, shown as the dot on
/// the app bar bell. Stubbed at 0 until Phase 8 adds the `notifications`
/// collection (its Firestore rules still deny all access).
// Phase 8 (approved stub exception, docs/PLAN.md): the live count.
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(myUnreadCountProvider).value ?? 0,
);
