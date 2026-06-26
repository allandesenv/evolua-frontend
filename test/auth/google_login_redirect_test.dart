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

    testWidgets('initial boot does not show auth page while session restores', (
      tester,
    ) async {
      final session = _testSession();
      final storage = _DelayedAuthSessionStorage();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: session),
          ),
          authSessionStorageProvider.overrideWithValue(storage),
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
      await tester.pump();

      expect(find.text('auth-page'), findsNothing);
      expect(find.text('home-page'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/',
      );

      storage.complete(jsonEncode(session.toJson()));
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
      expect(find.text('auth-page'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
    });

    testWidgets(
      'initial boot redirects to auth only after empty session read',
      (tester) async {
        final storage = _DelayedAuthSessionStorage();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(googleSession: _testSession()),
            ),
            authSessionStorageProvider.overrideWithValue(storage),
            profileRepositoryProvider.overrideWithValue(
              _FakeProfileRepository(),
            ),
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
        await tester.pump();

        expect(find.text('auth-page'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        storage.complete(null);
        await tester.pumpAndSettle();

        expect(find.text('auth-page'), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/auth',
        );
      },
    );

    testWidgets('invalid initial route shows boot splash while session loads', (
      tester,
    ) async {
      final storage = _DelayedAuthSessionStorage();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: _testSession()),
          ),
          authSessionStorageProvider.overrideWithValue(storage),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      final authRouterNotifier = _bindAuthRouterNotifier(container);
      addTearDown(authRouterNotifier.dispose);
      final router = _buildTestRouter(
        authRouterNotifier,
        initialLocation: '/rota-inexistente',
        overridePlatformDefaultLocation: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Page Not Found'), findsNothing);
      expect(find.text('Nao encontramos esta pagina.'), findsNothing);
    });

    testWidgets('invalid route after boot shows friendly not found page', (
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
      final router = _buildTestRouter(
        authRouterNotifier,
        initialLocation: '/rota-inexistente',
        overridePlatformDefaultLocation: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nao encontramos esta pagina.'), findsOneWidget);
      expect(find.text('Voltar para o Evolua'), findsOneWidget);
      expect(find.textContaining('Page Not Found'), findsNothing);
    });

    testWidgets('boot storage read failure is treated as empty session', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(googleSession: _testSession()),
          ),
          authSessionStorageProvider.overrideWithValue(
            _FailingAuthSessionStorage(),
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

      expect(find.text('auth-page'), findsOneWidget);
      expect(
        find.text('Nao conseguimos iniciar o Evolua agora.'),
        findsNothing,
      );
      expect(find.textContaining('Page Not Found'), findsNothing);
    });

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
      final router = _buildTestRouter(
        authRouterNotifier,
        initialLocation: '/auth',
      );

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

    testWidgets('public care claim route never redirects to auth', (
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
      final router = buildAppRouter(
        authRouterNotifier: authRouterNotifier,
        authPageBuilder: (context, state) =>
            const _PlaceholderPage('auth-page'),
        homePageBuilder: (context, state) =>
            const _PlaceholderPage('home-page'),
        careClaimPageBuilder: (context, state) =>
            const _PlaceholderPage('care-claim-page'),
        initialLocation: '/care/claim?sid=share-1&code=123456',
        overridePlatformDefaultLocation: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('care-claim-page'), findsOneWidget);
      expect(find.text('auth-page'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/care/claim',
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
      final repository = _FakeAuthRepository(googleSession: session);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
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
      expect(repository.exchangeCalls, 1);
    });

    testWidgets(
      'google callback waits for auth bootstrap before exchanging code',
      (tester) async {
        final storage = _DelayedAuthSessionStorage();
        final repository = _FakeAuthRepository(googleSession: _testSession());

        await _pumpGoogleCallbackScenario(
          tester,
          repository: repository,
          storage: storage,
          initialLocation: '/auth/google/callback?code=google-code',
          settle: false,
        );
        await tester.pump();

        expect(repository.exchangeCalls, 0);
        storage.complete(null);
        await tester.pumpAndSettle();

        expect(repository.exchangeCalls, 1);
        expect(find.text('home-page'), findsOneWidget);
      },
    );

    testWidgets('google callback times out when auth bootstrap stays loading', (
      tester,
    ) async {
      final storage = _DelayedAuthSessionStorage();
      final repository = _FakeAuthRepository(googleSession: _testSession());

      await _pumpGoogleCallbackScenario(
        tester,
        repository: repository,
        storage: storage,
        initialLocation: '/auth/google/callback?code=google-code',
        completionTimeout: const Duration(milliseconds: 20),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();

      expect(repository.exchangeCalls, 0);
      expect(find.text('Nao foi possivel entrar'), findsOneWidget);
      expect(
        find.text(
          'O login com Google demorou mais que o esperado. Tente novamente.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'google callback rebuilds errored auth provider once before exchange',
      (tester) async {
        final state = _CallbackAuthControllerState(
          session: _testSession(),
          failFirstBuild: true,
        );

        await _pumpGoogleCallbackWithAuthController(
          tester,
          state: state,
          initialLocation: '/auth/google/callback?code=google-code',
        );

        expect(state.buildCalls, 2);
        expect(state.completeCalls, 1);
        expect(find.text('home-page'), findsOneWidget);
      },
    );

    testWidgets(
      'google callback does not exchange when auth provider rebuild still fails',
      (tester) async {
        final state = _CallbackAuthControllerState(
          session: _testSession(),
          failEveryBuild: true,
        );

        await _pumpGoogleCallbackWithAuthController(
          tester,
          state: state,
          initialLocation: '/auth/google/callback?code=google-code',
        );

        expect(state.buildCalls, 2);
        expect(state.completeCalls, 0);
        expect(find.text('Nao foi possivel entrar'), findsOneWidget);
        expect(
          find.text('Falha ao concluir o login com Google.'),
          findsOneWidget,
        );
      },
    );

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

GoRouter _buildTestRouter(
  AuthRouterNotifier authRouterNotifier, {
  String initialLocation = '/',
  bool overridePlatformDefaultLocation = false,
}) {
  return buildAppRouter(
    authRouterNotifier: authRouterNotifier,
    authPageBuilder: (context, state) => const _PlaceholderPage('auth-page'),
    googleCallbackPageBuilder: (context, state) =>
        const _PlaceholderPage('callback-page'),
    homePageBuilder: (context, state) => const _PlaceholderPage('home-page'),
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: overridePlatformDefaultLocation,
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
  AuthSessionStorage? storage,
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
        storage ?? _SharedPreferencesAuthSessionStorage(),
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

Future<GoRouter> _pumpGoogleCallbackWithAuthController(
  WidgetTester tester, {
  required _CallbackAuthControllerState state,
  required String initialLocation,
  Duration completionTimeout = const Duration(seconds: 15),
}) async {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _CallbackAuthController(state)),
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
  await tester.pumpAndSettle();
  return router;
}

class _CallbackAuthControllerState {
  _CallbackAuthControllerState({
    required this.session,
    this.failFirstBuild = false,
    this.failEveryBuild = false,
  });

  final AuthSession session;
  final bool failFirstBuild;
  final bool failEveryBuild;
  int buildCalls = 0;
  int completeCalls = 0;
}

class _CallbackAuthController extends AuthController {
  _CallbackAuthController(this.fakeState);

  final _CallbackAuthControllerState fakeState;

  @override
  Future<AuthSession?> build() async {
    fakeState.buildCalls++;
    if (fakeState.failEveryBuild ||
        (fakeState.failFirstBuild && fakeState.buildCalls == 1)) {
      throw StateError('auth bootstrap failed');
    }
    return null;
  }

  @override
  Future<void> completeGoogleLogin({required String code}) async {
    fakeState.completeCalls++;
    state = AsyncData(fakeState.session);
  }
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

class _DelayedAuthSessionStorage implements AuthSessionStorage {
  final Completer<String?> _readCompleter = Completer<String?>();

  void complete(String? value) {
    if (!_readCompleter.isCompleted) {
      _readCompleter.complete(value);
    }
  }

  @override
  Future<String?> read() => _readCompleter.future;

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}

class _FailingAuthSessionStorage implements AuthSessionStorage {
  @override
  Future<String?> read() async {
    throw StateError('storage unavailable');
  }

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}

typedef _ExchangeHandler = Future<AuthSession> Function(String code);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.googleSession, this.exchangeHandler});

  final AuthSession googleSession;
  final _ExchangeHandler? exchangeHandler;
  int exchangeCalls = 0;

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    exchangeCalls++;
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
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> resendEmailVerification({required String accessToken}) async {}
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
