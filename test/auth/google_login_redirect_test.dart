import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:evolua_frontend/app/router/app_router.dart';
import 'package:evolua_frontend/app/router/auth_router_notifier.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/google_auth_callback_page.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionStorageKey = 'evolua.auth.session';

void main() {
  group('Google login redirect', () {
    test(
      'completeGoogleLogin saves session and restore works after rebuild',
      () async {
        SharedPreferences.setMockInitialValues({});
        final session = _testSession();

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(googleSession: session),
            ),
            authSessionStorageProvider.overrideWithValue(
              _SharedPreferencesAuthSessionStorage(),
            ),
            profileRepositoryProvider.overrideWithValue(
              _FakeProfileRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(authControllerProvider.future), isNull);

        await container
            .read(authControllerProvider.notifier)
            .completeGoogleLogin(code: 'google-code');
        expect(
          container.read(authControllerProvider).asData?.value?.email,
          session.email,
        );

        final restoredContainer = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(googleSession: session),
            ),
            authSessionStorageProvider.overrideWithValue(
              _SharedPreferencesAuthSessionStorage(),
            ),
            profileRepositoryProvider.overrideWithValue(
              _FakeProfileRepository(),
            ),
          ],
        );
        addTearDown(restoredContainer.dispose);

        final restored = await restoredContainer.read(
          authControllerProvider.future,
        );
        expect(restored?.userId, session.userId);
        expect(restored?.email, session.email);
      },
    );

    testWidgets('unauthenticated user trying /home is redirected to /auth', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: _testSession()),
          ),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
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
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/auth',
      );
    });

    testWidgets('authenticated user in /auth is redirected to /home', (
      tester,
    ) async {
      final session = _testSession();
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(session.toJson()),
      });

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: session),
          ),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
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
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
    });

    testWidgets('manual check-in navigation preserves previous page', (
      tester,
    ) async {
      final session = _testSession();
      SharedPreferences.setMockInitialValues({
        _sessionStorageKey: jsonEncode(session.toJson()),
      });

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: session),
          ),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      final authRouterNotifier = _bindAuthRouterNotifier(container);
      addTearDown(authRouterNotifier.dispose);
      final router = buildAppRouter(
        authRouterNotifier: authRouterNotifier,
        authPageBuilder: (context, state) =>
            const _PlaceholderPage('auth-page'),
        homePageBuilder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/check-in'),
              child: const Text('Fazer check-in'),
            ),
          ),
        ),
        checkInPageBuilder: (context, state) =>
            const _PlaceholderPage('check-in-page'),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();

      expect(find.text('check-in-page'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/check-in',
      );

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Fazer check-in'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
    });

    testWidgets('google callback exchanges code and redirects to /home', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final session = _testSession();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: session),
          ),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      final authRouterNotifier = _bindAuthRouterNotifier(container);
      addTearDown(authRouterNotifier.dispose);
      final router = buildAppRouter(
        authRouterNotifier: authRouterNotifier,
        authPageBuilder: (context, state) =>
            const _PlaceholderPage('auth-page'),
        homePageBuilder: (context, state) =>
            const _PlaceholderPage('home-page'),
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
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
    });

    testWidgets('direct google callback initial route redirects to /home', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final session = _testSession();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: session),
          ),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      final authRouterNotifier = _bindAuthRouterNotifier(container);
      addTearDown(authRouterNotifier.dispose);
      final router = _buildGoogleCallbackRouter(
        authRouterNotifier,
        initialLocation: '/auth/google/callback?code=google-code',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
    });

    testWidgets('google callback with error shows return action', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final router = await _pumpGoogleCallbackScenario(
        tester,
        initialLocation: '/auth/google/callback?error=access_denied',
      );

      expect(find.text('Nao foi possivel entrar'), findsOneWidget);
      expect(
        find.text('Nao foi possivel autenticar com Google.'),
        findsOneWidget,
      );
      expect(find.text('Voltar para login'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/auth/google/callback',
      );
    });

    testWidgets('google callback without code shows return action', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpGoogleCallbackScenario(
        tester,
        initialLocation: '/auth/google/callback',
      );

      expect(find.text('Nao foi possivel entrar'), findsOneWidget);
      expect(find.text('Callback de autenticacao sem codigo.'), findsOneWidget);
      expect(find.text('Voltar para login'), findsOneWidget);
    });

    testWidgets('google callback exchange failure shows visible error', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpGoogleCallbackScenario(
        tester,
        repository: _FakeAuthRepository(
          googleSession: _testSession(),
          exchangeHandler: (_) async => throw StateError('exchange failed'),
        ),
        initialLocation: '/auth/google/callback?code=google-code',
      );

      expect(find.text('Nao foi possivel entrar'), findsOneWidget);
      expect(
        find.text('Falha ao concluir o login com Google.'),
        findsOneWidget,
      );
      expect(find.text('Voltar para login'), findsOneWidget);
    });

    testWidgets('google callback slow exchange shows local loading', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final completer = Completer<AuthSession>();
      await _pumpGoogleCallbackScenario(
        tester,
        repository: _FakeAuthRepository(
          googleSession: _testSession(),
          exchangeHandler: (_) => completer.future,
        ),
        initialLocation: '/auth/google/callback?code=google-code',
        settle: false,
      );

      expect(find.text('Concluindo seu login com Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_testSession());
    });

    testWidgets('google callback timeout shows visible error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpGoogleCallbackScenario(
        tester,
        repository: _FakeAuthRepository(
          googleSession: _testSession(),
          exchangeHandler: (_) => Completer<AuthSession>().future,
        ),
        initialLocation: '/auth/google/callback?code=google-code',
        completionTimeout: const Duration(milliseconds: 20),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();

      expect(find.text('Nao foi possivel entrar'), findsOneWidget);
      expect(
        find.text(
          'O login com Google demorou mais que o esperado. Tente novamente.',
        ),
        findsOneWidget,
      );
      expect(find.text('Voltar para login'), findsOneWidget);
    });

    test(
      'completeGoogleLogin returns before slow profile sync finishes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final session = _testSession();
        final profileCompleter = Completer<Profile>();
        final profileRepository = _FakeProfileRepository(
          onUpsert: () => profileCompleter.future,
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(googleSession: session),
            ),
            authSessionStorageProvider.overrideWithValue(
              _SharedPreferencesAuthSessionStorage(),
            ),
            profileRepositoryProvider.overrideWithValue(profileRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.future);
        await container
            .read(authControllerProvider.notifier)
            .completeGoogleLogin(code: 'google-code')
            .timeout(const Duration(seconds: 1));

        expect(
          container.read(authControllerProvider).asData?.value?.email,
          session.email,
        );
        expect(profileRepository.upsertCalls, 1);
        expect(profileCompleter.isCompleted, isFalse);

        profileCompleter.complete(_testProfile(session));
      },
    );
  });
}

AuthRouterNotifier _bindAuthRouterNotifier(ProviderContainer container) {
  final notifier = AuthRouterNotifier();
  notifier.sync(container.read(authControllerProvider));

  container.listen<AsyncValue<AuthSession?>>(authControllerProvider, (
    previous,
    next,
  ) {
    final changed = notifier.sync(next);
    if (changed) {
      notifier.refresh();
    }
  }, fireImmediately: false);

  return notifier;
}

GoRouter _buildTestRouter(AuthRouterNotifier authRouterNotifier) {
  return buildAppRouter(
    authRouterNotifier: authRouterNotifier,
    authPageBuilder: (context, state) => const _PlaceholderPage('auth-page'),
    googleCallbackPageBuilder: (context, state) =>
        const _PlaceholderPage('callback-page'),
    homePageBuilder: (context, state) => const _PlaceholderPage('home-page'),
  );
}

GoRouter _buildGoogleCallbackRouter(
  AuthRouterNotifier authRouterNotifier, {
  String initialLocation = '/auth',
  Duration completionTimeout = const Duration(seconds: 15),
}) {
  return buildAppRouter(
    authRouterNotifier: authRouterNotifier,
    authPageBuilder: (context, state) => const _PlaceholderPage('auth-page'),
    homePageBuilder: (context, state) => const _PlaceholderPage('home-page'),
    googleCallbackPageBuilder: (context, state) => GoogleAuthCallbackPage(
      code: state.uri.queryParameters['code'],
      error: state.uri.queryParameters['error'],
      completionTimeout: completionTimeout,
    ),
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: true,
  );
}

Future<GoRouter> _pumpGoogleCallbackScenario(
  WidgetTester tester, {
  _FakeAuthRepository? repository,
  required String initialLocation,
  Duration completionTimeout = const Duration(seconds: 15),
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        repository ?? _FakeAuthRepository(googleSession: _testSession()),
      ),
      authSessionStorageProvider.overrideWithValue(
        _SharedPreferencesAuthSessionStorage(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    ],
  );
  addTearDown(container.dispose);

  final authRouterNotifier = _bindAuthRouterNotifier(container);
  addTearDown(authRouterNotifier.dispose);
  final router = _buildGoogleCallbackRouter(
    authRouterNotifier,
    initialLocation: initialLocation,
    completionTimeout: completionTimeout,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
  return router;
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _SharedPreferencesAuthSessionStorage implements AuthSessionStorage {
  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_sessionStorageKey);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionStorageKey, value);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionStorageKey);
  }
}

typedef _ExchangeHandler = Future<AuthSession> Function(String code);

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({
    required this.googleSession,
    this.exchangeHandler,
  });

  final AuthSession googleSession;
  final _ExchangeHandler? exchangeHandler;

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    final handler = exchangeHandler;
    if (handler != null) {
      return handler(code);
    }
    return googleSession;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return googleSession;
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    return googleSession;
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.onUpsert});

  final Future<Profile> Function()? onUpsert;
  int upsertCalls = 0;

  @override
  Future<Profile?> getMe() async {
    return null;
  }

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) async {
    upsertCalls += 1;
    final upsert = onUpsert;
    if (upsert != null) {
      return upsert();
    }

    return _testProfile(
      _testSession(),
      displayName: displayName,
      birthDate: birthDate,
      gender: gender,
      customGender: customGender,
      bio: bio,
      journeyLevel: journeyLevel,
    );
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return '';
  }
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

Profile _testProfile(
  AuthSession session, {
  String? displayName,
  DateTime? birthDate,
  String? gender,
  String? customGender,
  String bio = '',
  int journeyLevel = 1,
}) {
  return Profile(
    id: 1,
    userId: session.userId,
    displayName:
        displayName ?? session.displayName ?? session.email.split('@').first,
    bio: bio,
    journeyLevel: journeyLevel,
    premium: false,
    birthDate: birthDate,
    gender: gender,
    customGender: customGender,
    avatarUrl: session.avatarUrl,
    createdAt: DateTime.now(),
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
