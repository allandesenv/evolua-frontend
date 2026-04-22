import 'dart:convert';

import 'package:evolua_frontend/app/router/app_router.dart';
import 'package:evolua_frontend/app/router/auth_router_notifier.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/google_auth_callback_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionStorageKey = 'evolua.auth.session';

void main() {
  group('Google login redirect', () {
    test('completeGoogleLogin saves session and restore works after rebuild', () async {
      SharedPreferences.setMockInitialValues({});
      final session = _testSession();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(googleSession: session)),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(authControllerProvider.future), isNull);

      await container.read(authControllerProvider.notifier).completeGoogleLogin(code: 'google-code');
      expect(container.read(authControllerProvider).asData?.value?.email, session.email);

      final restoredContainer = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(googleSession: session)),
        ],
      );
      addTearDown(restoredContainer.dispose);

      final restored = await restoredContainer.read(authControllerProvider.future);
      expect(restored?.userId, session.userId);
      expect(restored?.email, session.email);
    });

    testWidgets('unauthenticated user trying /home is redirected to /auth', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(googleSession: _testSession())),
        ],
      );
      addTearDown(container.dispose);

      final authRouterNotifier = _bindAuthRouterNotifier(container);
      addTearDown(authRouterNotifier.dispose);
      final router = _buildTestRouter(authRouterNotifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      router.go('/home');
      await tester.pumpAndSettle();

      expect(find.text('auth-page'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/auth');
    });

    testWidgets('authenticated user in /auth is redirected to /home', (tester) async {
      final session = _testSession();
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(session.toJson()),
      });

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(googleSession: session)),
        ],
      );
      addTearDown(container.dispose);

      final authRouterNotifier = _bindAuthRouterNotifier(container);
      addTearDown(authRouterNotifier.dispose);
      final router = _buildTestRouter(authRouterNotifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/home');
    });

    testWidgets('google callback exchanges code and redirects to /home', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = _testSession();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(googleSession: session)),
        ],
      );
      addTearDown(container.dispose);

      final authRouterNotifier = _bindAuthRouterNotifier(container);
      addTearDown(authRouterNotifier.dispose);
      final router = buildAppRouter(
        authRouterNotifier: authRouterNotifier,
        authPageBuilder: (context, state) => const _PlaceholderPage('auth-page'),
        homePageBuilder: (context, state) => const _PlaceholderPage('home-page'),
        googleCallbackPageBuilder: (context, state) => GoogleAuthCallbackPage(
          code: state.uri.queryParameters['code'],
          error: state.uri.queryParameters['error'],
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      router.go('/auth/google/callback?code=google-code');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/home');
    });
  });
}

AuthRouterNotifier _bindAuthRouterNotifier(ProviderContainer container) {
  final notifier = AuthRouterNotifier();
  notifier.sync(container.read(authControllerProvider));

  container.listen<AsyncValue<AuthSession?>>(
    authControllerProvider,
    (previous, next) {
      final changed = notifier.sync(next);
      if (changed) {
        notifier.refresh();
      }
    },
    fireImmediately: false,
  );

  return notifier;
}

GoRouter _buildTestRouter(AuthRouterNotifier authRouterNotifier) {
  return buildAppRouter(
    authRouterNotifier: authRouterNotifier,
    authPageBuilder: (context, state) => const _PlaceholderPage('auth-page'),
    googleCallbackPageBuilder: (context, state) => const _PlaceholderPage('callback-page'),
    homePageBuilder: (context, state) => const _PlaceholderPage('home-page'),
  );
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label),
      ),
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({
    required this.googleSession,
  });

  final AuthSession googleSession;

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    return googleSession;
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    return googleSession;
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}
}

AuthSession _testSession() {
  return AuthSession(
    userId: 'user-123',
    email: 'google-user@evolua.app',
    roles: const ['ROLE_USER'],
    accessToken: _buildJwt(
      sub: 'user-123',
      email: 'google-user@evolua.app',
      roles: const ['ROLE_USER'],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
    refreshToken: 'refresh-token',
  );
}

String _buildJwt({
  required String sub,
  required String email,
  required List<String> roles,
  required DateTime expiresAt,
}) {
  String encode(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': sub,
    'email': email,
    'roles': roles,
    'exp': expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
  });

  return '$header.$payload.signature';
}
