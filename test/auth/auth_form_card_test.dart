import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/app/router/app_router.dart';
import 'package:evolua_frontend/app/router/auth_router_notifier.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/auth/presentation/pages/auth_page.dart';
import 'package:evolua_frontend/features/auth/presentation/utils/google_oauth_launcher_provider.dart';
import 'package:evolua_frontend/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionStorageKey = 'evolua.auth.session';

void main() {
  group('AuthFormCard', () {
    testWidgets('logs in successfully, shows loading and redirects home', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final loginCompleter = Completer<AuthSession>();
      final repository = _FakeAuthRepository(
        loginHandler: ({required email, required password}) {
          return loginCompleter.future;
        },
      );
      final container = _buildContainer(repository);
      addTearDown(container.dispose);

      final notifier = _bindAuthRouterNotifier(container);
      addTearDown(notifier.dispose);
      final router = _buildRouter(notifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        ' USER@Evolua.App ',
      );
      await tester.enterText(find.byType(TextFormField).at(1), ' 123456 ');
      await _tapSubmit(tester, 'Entrar');
      await tester.pump();

      expect(repository.loginCalls, 1);
      expect(repository.lastLoginEmail, 'user@evolua.app');
      expect(repository.lastLoginPassword, ' 123456 ');
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      final loadingButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(loadingButton.onPressed, isNull);
      expect(repository.loginCalls, 1);

      loginCompleter.complete(_testSession());
      await tester.pumpAndSettle();

      expect(find.text('home-page'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
    });

    testWidgets('blocks invalid login input and focuses first invalid field', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FakeAuthRepository();

      await tester.pumpWidget(_testApp(repository: repository));

      await _tapSubmit(tester, 'Entrar');
      await tester.pump();

      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);
      expect(repository.loginCalls, 0);
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot(''));

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'email-invalido',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await _tapSubmit(tester, 'Entrar');
      await tester.pump();

      expect(find.text('Use um e-mail válido.'), findsOneWidget);
      expect(
        find.text('A senha deve ter ao menos 6 caracteres.'),
        findsOneWidget,
      );
      expect(repository.loginCalls, 0);
    });

    testWidgets(
      'shows safe backend login error without revealing account state',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final repository = _FakeAuthRepository(
          loginHandler: ({required email, required password}) async {
            throw DioException(
              requestOptions: RequestOptions(path: '/v1/public/auth/login'),
              response: Response(
                requestOptions: RequestOptions(path: '/v1/public/auth/login'),
                statusCode: 401,
                data: {
                  'details': ['Credenciais invalidas.'],
                },
              ),
            );
          },
        );

        await tester.pumpWidget(_testApp(repository: repository));
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'ghost@evolua.app',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '123456');
        await _tapSubmit(tester, 'Entrar');
        await tester.pumpAndSettle();

        expect(find.text('Credenciais invalidas.'), findsOneWidget);
        expect(find.textContaining('existe'), findsNothing);
      },
    );

    testWidgets('toggles password visibility and sends forgot password email', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FakeAuthRepository();
      await tester.pumpWidget(_testApp(repository: repository));

      final passwordField = find.byType(EditableText).last;
      expect(tester.widget<EditableText>(passwordField).obscureText, isTrue);

      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(tester.widget<EditableText>(passwordField).obscureText, isFalse);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        ' USER@Evolua.App ',
      );
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar senha'), findsOneWidget);

      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();
      expect(repository.lastForgotPasswordEmail, 'user@evolua.app');
      expect(find.text('Reenviar link'), findsOneWidget);
      expect(find.textContaining('instruções de recuperação'), findsOneWidget);

      final forgotButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Esqueci minha senha'),
      );
      expect(
        forgotButton.style?.tapTargetSize,
        MaterialTapTargetSize.shrinkWrap,
      );
    });

    testWidgets('shows forgot password loading and blocks duplicate resend', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final forgotCompleter = Completer<void>();
      final repository = _FakeAuthRepository(
        forgotPasswordHandler: ({required email}) => forgotCompleter.future,
      );
      await tester.pumpWidget(_testApp(repository: repository));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'user@evolua.app',
      );
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar link'));
      await tester.pump();

      expect(repository.forgotPasswordCalls, 1);
      expect(find.text('Enviando...'), findsOneWidget);

      await tester.tap(find.text('Enviando...'), warnIfMissed: false);
      await tester.pump();
      expect(repository.forgotPasswordCalls, 1);

      forgotCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('Reenviar link'), findsOneWidget);
      expect(find.text('Fechar'), findsOneWidget);
    });

    testWidgets('keeps forgot password dialog open on timeout', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = _FakeAuthRepository(
        forgotPasswordHandler: ({required email}) async {
          throw DioException(
            type: DioExceptionType.receiveTimeout,
            requestOptions: RequestOptions(
              path: '/v1/public/auth/password/forgot',
            ),
          );
        },
      );
      await tester.pumpWidget(_testApp(repository: repository));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'user@evolua.app',
      );
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar senha'), findsOneWidget);
      expect(
        find.textContaining('Não conseguimos confirmar o envio agora'),
        findsOneWidget,
      );
      expect(find.text('user@evolua.app'), findsWidgets);
      expect(repository.forgotPasswordCalls, 1);
    });

    testWidgets('starts Google OAuth once and disables duplicate click', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final launchedUrls = <String>[];

      await tester.pumpWidget(
        _testApp(
          repository: _FakeAuthRepository(),
          googleLauncher: (url) async => launchedUrls.add(url),
        ),
      );

      await _startGoogleOAuth(tester);
      await tester.pump();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Continuar com Google'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(launchedUrls, hasLength(1));
      expect(launchedUrls.single, contains('/v1/public/auth/google/start'));
      expect(launchedUrls.single, contains('frontendRedirectUri='));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows friendly OAuth launcher failure', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        _testApp(
          repository: _FakeAuthRepository(),
          googleLauncher: (_) async => throw UnsupportedError('blocked'),
        ),
      );

      await _startGoogleOAuth(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('Não foi possível iniciar o login com Google'),
        findsOneWidget,
      );
    });

    testWidgets('registers with valid data and prevents duplicate submit', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final registerCompleter = Completer<void>();
      final repository = _FakeAuthRepository(
        registerHandler:
            ({required displayName, required email, required password}) {
              return registerCompleter.future;
            },
      );

      await tester.pumpWidget(
        _testApp(repository: repository, initialRegisterMode: true),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        '  José da Silva  ',
      );
      await tester.tap(find.byKey(const Key('auth-birth-date-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        ' NOVO@Evolua.App ',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        ' senha com espaco ',
      );

      await _tapSubmit(tester, 'Criar conta');
      await tester.pump();
      final loadingButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(loadingButton.onPressed, isNull);

      expect(repository.registerCalls, 1);
      expect(repository.lastRegisterName, 'José da Silva');
      expect(repository.lastRegisterEmail, 'novo@evolua.app');
      expect(repository.lastRegisterPassword, ' senha com espaco ');

      registerCompleter.complete();
      await tester.pumpAndSettle();
      expect(repository.loginCalls, 1);
    });

    testWidgets(
      'validates register name, birth date, gender and custom gender',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final repository = _FakeAuthRepository();

        await tester.pumpWidget(
          _testApp(repository: repository, initialRegisterMode: true),
        );

        await tester.enterText(find.byType(TextFormField).at(0), 'A1');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'valid@evolua.app',
        );
        await tester.enterText(find.byType(TextFormField).at(2), '123456');
        await _tapSubmit(tester, 'Criar conta');
        await tester.pump();

        expect(find.textContaining('Use apenas letras'), findsOneWidget);
        expect(find.text('Informe sua data de nascimento.'), findsOneWidget);
        expect(repository.registerCalls, 0);

        await tester.tap(find.text('Masculino'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Personalizado').last);
        await tester.pumpAndSettle();
        await _tapSubmit(tester, 'Criar conta');
        await tester.pump();

        expect(find.text('Informe como você se identifica.'), findsOneWidget);
      },
    );

    testWidgets('renders compact mobile auth page without duplicate title', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _authPageTestApp(repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Evolua'), findsOneWidget);
      expect(find.text('Continue sua jornada'), findsOneWidget);
      expect(find.text('Entre e continue sua jornada'), findsNothing);
      expect(find.text('Check-in rapido'), findsNothing);
      expect(find.text('Trilhas curtas'), findsNothing);
      expect(find.text('Reflexoes do momento'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Continuar com Google'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
      expect(find.byKey(const Key('auth-submit-button')), findsOneWidget);
    });
  });
}

Future<void> _tapSubmit(WidgetTester tester, String label) async {
  await tester.pump();
  final button = find.byKey(const Key('auth-submit-button'));
  await tester.ensureVisible(button);
  final widget = tester.widget<ElevatedButton>(button);
  final onPressed = widget.onPressed;
  expect(onPressed, isNotNull);
  onPressed!();
  await tester.pump();
}

Future<void> _startGoogleOAuth(WidgetTester tester) async {
  await tester.pump();
  final button = find.widgetWithText(OutlinedButton, 'Continuar com Google');
  final widget = tester.widget<OutlinedButton>(button);
  final onPressed = widget.onPressed;
  expect(onPressed, isNotNull);
  onPressed!();
}

ProviderContainer _buildContainer(_FakeAuthRepository repository) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authSessionStorageProvider.overrideWithValue(
        _SharedPreferencesAuthSessionStorage(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    ],
  );
}

Widget _testApp({
  required _FakeAuthRepository repository,
  GoogleOAuthLauncher? googleLauncher,
  bool initialRegisterMode = false,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authSessionStorageProvider.overrideWithValue(
        _SharedPreferencesAuthSessionStorage(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      if (googleLauncher != null)
        googleOAuthLauncherProvider.overrideWithValue(googleLauncher),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: AuthFormCard(initialRegisterMode: initialRegisterMode),
        ),
      ),
    ),
  );
}

Widget _authPageTestApp({required _FakeAuthRepository repository}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authSessionStorageProvider.overrideWithValue(
        _SharedPreferencesAuthSessionStorage(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    ],
    child: const MaterialApp(home: AuthPage()),
  );
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

GoRouter _buildRouter(AuthRouterNotifier authRouterNotifier) {
  return buildAppRouter(
    authRouterNotifier: authRouterNotifier,
    authPageBuilder: (context, state) => const AuthPage(),
    homePageBuilder: (context, state) => const _PlaceholderPage('home-page'),
  );
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

typedef _LoginHandler =
    Future<AuthSession> Function({
      required String email,
      required String password,
    });

typedef _RegisterHandler =
    Future<void> Function({
      required String displayName,
      required String email,
      required String password,
    });

typedef _ForgotPasswordHandler = Future<void> Function({required String email});

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.loginHandler,
    this.registerHandler,
    this.forgotPasswordHandler,
  });

  final _LoginHandler? loginHandler;
  final _RegisterHandler? registerHandler;
  final _ForgotPasswordHandler? forgotPasswordHandler;
  int loginCalls = 0;
  int registerCalls = 0;
  int forgotPasswordCalls = 0;
  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastRegisterName;
  String? lastRegisterEmail;
  String? lastRegisterPassword;
  String? lastForgotPasswordEmail;
  String? lastResetToken;
  String? lastResetPassword;

  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    return _testSession();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    lastLoginEmail = email;
    lastLoginPassword = password;
    final handler = loginHandler;
    if (handler != null) {
      return handler(email: email, password: password);
    }
    return _testSession(email: email);
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    return _testSession();
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    forgotPasswordCalls += 1;
    lastForgotPasswordEmail = email;
    final handler = forgotPasswordHandler;
    if (handler != null) {
      return handler(email: email);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    lastResetToken = token;
    lastResetPassword = newPassword;
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    registerCalls += 1;
    lastRegisterName = displayName;
    lastRegisterEmail = email;
    lastRegisterPassword = password;
    final handler = registerHandler;
    if (handler != null) {
      return handler(
        displayName: displayName,
        email: email,
        password: password,
      );
    }
  }
}

class _FakeProfileRepository implements ProfileRepository {
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
    return Profile(
      id: 1,
      userId: 'user-123',
      displayName: displayName,
      bio: bio,
      journeyLevel: journeyLevel,
      premium: false,
      birthDate: birthDate,
      gender: gender,
      customGender: customGender,
      avatarUrl: null,
      createdAt: DateTime(2026, 1, 1),
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

AuthSession _testSession({String email = 'user@evolua.app'}) {
  return AuthSession(
    userId: 'user-123',
    email: email,
    roles: const ['ROLE_USER'],
    accessToken: _buildJwt(
      sub: 'user-123',
      email: email,
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
