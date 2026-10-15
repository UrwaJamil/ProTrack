import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';

/// Bridges [authControllerProvider] into go_router's `refreshListenable` so
/// the router re-evaluates `redirect` whenever auth state changes, without
/// rebuilding the GoRouter object itself (which would lose navigation
/// state).
final routerRefreshProvider = Provider<_GoRouterRefreshNotifier>(
  (ref) => _GoRouterRefreshNotifier(ref),
);

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}
