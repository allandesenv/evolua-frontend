import 'package:evolua_frontend/app/router/auth_router_notifier.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/auth_page.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/google_auth_callback_page.dart';
import 'package:evolua_frontend/features/home/presentation/pages/home_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRouterNotifier = AuthRouterNotifier();
  authRouterNotifier.sync(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (previous, next) {
    final changed = authRouterNotifier.sync(next);
    if (changed) {
      authRouterNotifier.refresh();
    }
  });
  ref.onDispose(authRouterNotifier.dispose);

  return buildAppRouter(authRouterNotifier: authRouterNotifier);
});

GoRouter buildAppRouter({
  required AuthRouterNotifier authRouterNotifier,
  GoRouterWidgetBuilder? authPageBuilder,
  GoRouterWidgetBuilder? googleCallbackPageBuilder,
  GoRouterWidgetBuilder? homePageBuilder,
}) {
  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: authRouterNotifier,
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => authRouterNotifier.isAuthenticated ? '/home' : '/auth',
      ),
      GoRoute(
        path: '/auth',
        builder: authPageBuilder ?? (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/auth/google/callback',
        builder:
            googleCallbackPageBuilder ??
            (context, state) => GoogleAuthCallbackPage(
                  code: state.uri.queryParameters['code'],
                  error: state.uri.queryParameters['error'],
                ),
      ),
      GoRoute(
        path: '/home',
        builder: homePageBuilder ?? (context, state) => const HomePage(),
      ),
    ],
    redirect: (context, state) {
      if (authRouterNotifier.isBootstrapping) {
        return null;
      }

      final goingToAuth = state.matchedLocation.startsWith('/auth');

      if (!authRouterNotifier.isAuthenticated && !goingToAuth) {
        return '/auth';
      }

      if (authRouterNotifier.isAuthenticated && goingToAuth) {
        return '/home';
      }

      return null;
    },
  );
}
