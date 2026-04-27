import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier();

  bool _isAuthenticated = false;
  bool _isBootstrapping = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isBootstrapping => _isBootstrapping;

  bool sync(AsyncValue<AuthSession?> authState) {
    final nextAuthenticated = authState.asData?.value != null;
    final nextBootstrapping = authState.isLoading && !authState.hasValue;

    final changed =
        nextAuthenticated != _isAuthenticated || nextBootstrapping != _isBootstrapping;

    _isAuthenticated = nextAuthenticated;
    _isBootstrapping = nextBootstrapping;
    return changed;
  }

  void refresh() {
    notifyListeners();
  }
}
