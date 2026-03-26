import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/auth_page.dart';
import 'package:evolua_frontend/features/home/presentation/pages/home_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final isAuthenticated = authState.asData?.value != null;
  final isBootstrapping = authState.isLoading && !authState.hasValue;

  return GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
    ],
    redirect: (context, state) {
      if (isBootstrapping) {
        return null;
      }

      final goingToAuth = state.matchedLocation == '/auth';

      if (!isAuthenticated && !goingToAuth) {
        return '/auth';
      }

      if (isAuthenticated && goingToAuth) {
        return '/home';
      }

      return null;
    },
  );
});
