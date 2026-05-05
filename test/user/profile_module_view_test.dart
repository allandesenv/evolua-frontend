import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:evolua_frontend/features/user/application/accessibility_preferences_controller.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/application/settings_privacy_preferences_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:evolua_frontend/features/user/presentation/widgets/profile_module_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    _remoteSettingsPayload = _defaultRemoteSettings();
    _remoteAccessibilityPayload = _defaultRemoteAccessibility();
    _feedbackShouldFail = false;
    _lastFeedbackPayload = null;
  });

  testWidgets('keeps profile hero readable on compact width', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
          authenticatedDioProvider(
            AppConfig.authBaseUrl,
          ).overrideWithValue(_fakeAuthDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileModuleView(section: ProfileModuleSection.feedback),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Leo Respiro' &&
            widget.maxLines == 2 &&
            widget.overflow == TextOverflow.ellipsis,
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Trocar foto'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Atualizar'), findsOneWidget);
    expect(find.text('Planos e assinaturas'), findsOneWidget);
    expect(find.textContaining('Voce esta no plano essencial'), findsNothing);

    await tester.tap(find.text('Planos e assinaturas'));
    await tester.pumpAndSettle();

    expect(find.text('Planos e assinaturas'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Voce esta no plano essencial'), findsOneWidget);
  });

  testWidgets('renders settings and privacy controls on compact width', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
          authenticatedDioProvider(
            AppConfig.authBaseUrl,
          ).overrideWithValue(_fakeAuthDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileModuleView(
                section: ProfileModuleSection.settingsPrivacy,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configuracoes e privacidade'), findsAtLeastNWidgets(1));
    expect(find.text('Conta e acesso'), findsOneWidget);
    expect(find.text('Privacidade emocional'), findsOneWidget);
    expect(find.text('Dados e seguranca'), findsOneWidget);
    expect(find.text('Personalizacao da experiencia'), findsOneWidget);
    expect(find.text('E-mail de acesso'), findsOneWidget);
    expect(find.text('leo@evolua.local'), findsAtLeastNWidgets(1));
    expect(find.text('Tornar diario privado'), findsOneWidget);
    expect(find.text('Baixar meus dados'), findsAtLeastNWidgets(1));
    expect(find.text('Tom da IA'), findsOneWidget);

    await tester.ensureVisible(find.text('Salvar preferencias'));
    await tester.tap(find.text('Salvar preferencias'));
    await tester.pumpAndSettle();

    expect(find.text('Preferencias salvas com seguranca.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders help support and creates real ticket', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
          authenticatedDioProvider(
            AppConfig.authBaseUrl,
          ).overrideWithValue(_fakeAuthDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileModuleView(
                section: ProfileModuleSection.helpSupport,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajuda e suporte'), findsAtLeastNWidgets(1));
    expect(find.text('Central de ajuda'), findsOneWidget);
    expect(find.text('Suporte humano'), findsOneWidget);
    expect(find.text('Bem-estar e suporte emocional'), findsOneWidget);
    expect(find.text('Status da plataforma'), findsOneWidget);
    expect(find.text('Como funcionam as trilhas?'), findsOneWidget);
    expect(find.text('Sistema operacional'), findsOneWidget);
    expect(find.text('IA operacional'), findsOneWidget);

    await tester.ensureVisible(find.text('Como funcionam as trilhas?'));
    await tester.tap(find.text('Como funcionam as trilhas?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('As trilhas organizam praticas'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Abrir chamado').first);
    await tester.tap(find.text('Abrir chamado').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Preciso de ajuda.');
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar chamado'));
    await tester.pumpAndSettle();

    expect(
      find.text('Chamado #42 aberto. Nosso time vai acompanhar com cuidado.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders feedback form and submits real feedback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
          authenticatedDioProvider(
            AppConfig.authBaseUrl,
          ).overrideWithValue(_fakeAuthDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileModuleView(section: ProfileModuleSection.feedback),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dar feedback'), findsAtLeastNWidgets(1));
    expect(find.text('Compartilhe sua experiencia'), findsOneWidget);
    expect(find.text('Sugerir melhoria'), findsOneWidget);
    expect(find.text('Reportar problema'), findsOneWidget);
    expect(find.text('Avaliacao rapida'), findsOneWidget);
    expect(find.text('Enviar feedback'), findsOneWidget);

    await tester.enterText(
      _feedbackTextField('O que esta funcionando bem?'),
      'As trilhas estao claras.',
    );
    await tester.ensureVisible(find.text('Boa'));
    await tester.tap(find.text('Boa'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar feedback'));
    await tester.tap(find.text('Enviar feedback'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Feedback #99 enviado. Obrigado por construir o Evolua com a gente.',
      ),
      findsOneWidget,
    );
    expect(_lastFeedbackPayload?['workingWell'], 'As trilhas estao claras.');
    expect(_lastFeedbackPayload?['rating'], 'BOA');
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps feedback fields when backend returns error', (
    tester,
  ) async {
    _feedbackShouldFail = true;
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
          authenticatedDioProvider(
            AppConfig.authBaseUrl,
          ).overrideWithValue(_fakeAuthDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileModuleView(section: ProfileModuleSection.feedback),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      _feedbackTextField('O que poderia melhorar?'),
      'O carregamento da home.',
    );
    await tester.ensureVisible(find.text('Enviar feedback'));
    await tester.tap(find.text('Enviar feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Falha simulada no feedback.'), findsOneWidget);
    expect(find.text('O carregamento da home.'), findsOneWidget);
  });

  testWidgets('renders accessibility settings and persists controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 1040));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDisplayAccessibility(tester);

    expect(find.text('Tela e acessibilidade'), findsAtLeastNWidgets(1));
    expect(find.text('Aparencia'), findsOneWidget);
    expect(find.text('Leitura e legibilidade'), findsOneWidget);
    expect(find.text('Navegacao e interacao'), findsOneWidget);
    expect(find.text('Acessibilidade emocional'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Contraste elevado'), findsOneWidget);
    expect(find.text('Tamanho do texto'), findsOneWidget);

    await tester.ensureVisible(find.text('Claro'));
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Contraste elevado'));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tamanho do texto'));
    await tester.tap(find.text('Normal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grande').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar preferencias visuais'));
    await tester.tap(find.text('Salvar preferencias visuais'));
    await tester.pumpAndSettle();

    final sharedPreferences = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(
              sharedPreferences.getString(accessibilityPreferencesStorageKey)!,
            )
            as Map<String, dynamic>;

    expect(saved['themeMode'], 'light');
    expect(saved['highContrast'], isTrue);
    expect(saved['textSize'], 'large');
    expect(
      find.text('Preferencias visuais salvas com conforto.'),
      findsOneWidget,
    );
  });

  testWidgets('persists settings and reloads saved controls', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });

    await _pumpSettingsPrivacy(tester);

    await tester.ensureVisible(find.text('Tornar diario privado'));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tom da IA'));
    await tester.tap(find.text('Mais acolhedor').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais direto').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar preferencias'));
    await tester.tap(find.text('Salvar preferencias'));
    await tester.pumpAndSettle();

    final sharedPreferences = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(
              sharedPreferences.getString(
                settingsPrivacyPreferencesStorageKey,
              )!,
            )
            as Map<String, dynamic>;

    expect(saved['privateJournal'], isFalse);
    expect(saved['aiTone'], 'direto');

    await _pumpSettingsPrivacy(tester);

    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(find.text('Mais direto'), findsOneWidget);
  });

  testWidgets('exports local settings data as json', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    final clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardCalls.add(call);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await _pumpSettingsPrivacy(tester);

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Baixar meus dados'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Baixar meus dados'));
    await tester.pumpAndSettle();

    expect(find.text('Baixar meus dados'), findsAtLeastNWidgets(1));
    expect(find.textContaining('"email": "leo@evolua.local"'), findsOneWidget);
    expect(find.textContaining('"privateJournal": true'), findsOneWidget);
    expect(
      find.textContaining('Exportacao gerada pelo backend Evolua'),
      findsOneWidget,
    );
    expect(clipboardCalls, isNotEmpty);
  });

  testWidgets('deactivates and deletes account through guarded dialogs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });

    await _pumpSettingsPrivacy(tester);

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Desativar conta'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desativar conta'));
    await tester.pumpAndSettle();
    expect(find.text('Desativar conta'), findsAtLeastNWidgets(1));
    await tester.enterText(find.byType(TextField).last, 'leo@evolua.local');
    await tester.tap(find.widgetWithText(FilledButton, 'Desativar conta').last);
    await tester.pumpAndSettle();

    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await _pumpSettingsPrivacy(tester);

    await tester.ensureVisible(find.text('Excluir conta'));
    await tester.tap(find.text('Excluir conta').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'leo@evolua.local');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir conta').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSettingsPrivacy(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        subscriptionRepositoryProvider.overrideWithValue(
          _FakeSubscriptionRepository(),
        ),
        authenticatedDioProvider(
          AppConfig.userBaseUrl,
        ).overrideWithValue(_fakeUserDio()),
        authenticatedDioProvider(
          AppConfig.authBaseUrl,
        ).overrideWithValue(_fakeAuthDio()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ProfileModuleView(
              section: ProfileModuleSection.settingsPrivacy,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDisplayAccessibility(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        subscriptionRepositoryProvider.overrideWithValue(
          _FakeSubscriptionRepository(),
        ),
        authenticatedDioProvider(
          AppConfig.userBaseUrl,
        ).overrideWithValue(_fakeUserDio()),
        authenticatedDioProvider(
          AppConfig.authBaseUrl,
        ).overrideWithValue(_fakeAuthDio()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ProfileModuleView(
              section: ProfileModuleSection.displayAccessibility,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Dio _fakeUserDio() {
  return Dio()..httpClientAdapter = _FakeUserAdapter();
}

Dio _fakeAuthDio() {
  return Dio()..httpClientAdapter = _FakeAuthAdapter();
}

class _FakeUserAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' &&
        options.path == '/v1/profiles/me/privacy-settings') {
      return _jsonResponse({'data': _remoteSettingsPayload});
    }
    if (options.method == 'PUT' &&
        options.path == '/v1/profiles/me/privacy-settings') {
      _remoteSettingsPayload = Map<String, dynamic>.from(options.data as Map);
      return _jsonResponse({'data': _remoteSettingsPayload});
    }
    if (options.method == 'GET' &&
        options.path == '/v1/profiles/me/accessibility-settings') {
      return _jsonResponse({'data': _remoteAccessibilityPayload});
    }
    if (options.method == 'PUT' &&
        options.path == '/v1/profiles/me/accessibility-settings') {
      _remoteAccessibilityPayload = Map<String, dynamic>.from(
        options.data as Map,
      );
      return _jsonResponse({'data': _remoteAccessibilityPayload});
    }
    if (options.method == 'GET' &&
        options.path == '/v1/profiles/me/data-export') {
      return _jsonResponse({
        'data': {
          'email': 'leo@evolua.local',
          'preferences': {'privateJournal': true},
          'exportedAt': '2026-05-05T00:00:00Z',
          'message': 'Exportacao gerada pelo backend Evolua.',
        },
      });
    }
    if (options.method == 'GET' && options.path == '/v1/support/config') {
      return _jsonResponse({
        'data': {
          'helpCenterUrl': 'https://help.evolua.local',
          'supportUrl': 'https://support.evolua.local',
          'professionalHelpUrl': 'https://care.evolua.local',
          'emotionalResourcesUrl': 'https://resources.evolua.local',
          'aiLimitsUrl': 'https://limits.evolua.local',
        },
      });
    }
    if (options.method == 'GET' && options.path == '/v1/support/status') {
      return _jsonResponse({
        'data': [
          {
            'key': 'system',
            'label': 'Sistema operacional',
            'state': 'OPERATIONAL',
            'detail': 'Funcionando normalmente.',
          },
          {
            'key': 'ai',
            'label': 'IA operacional',
            'state': 'UNKNOWN',
            'detail': 'Nao foi possivel confirmar agora.',
          },
          {
            'key': 'notifications',
            'label': 'Notificacoes',
            'state': 'OPERATIONAL',
            'detail': 'Funcionando normalmente.',
          },
          {
            'key': 'sync',
            'label': 'Sincronizacao',
            'state': 'OPERATIONAL',
            'detail': 'Funcionando normalmente.',
          },
        ],
      });
    }
    if (options.method == 'POST' && options.path == '/v1/support/tickets') {
      return _jsonResponse({
        'data': {
          'id': 42,
          'category': (options.data as Map)['category'],
          'status': 'OPEN',
          'createdAt': '2026-05-05T00:00:00Z',
        },
      }, statusCode: 201);
    }
    if (options.method == 'POST' && options.path == '/v1/feedback') {
      if (_feedbackShouldFail) {
        return _jsonResponse({
          'message': 'Bad Request',
          'details': ['Falha simulada no feedback.'],
        }, statusCode: 400);
      }
      final formData = options.data as FormData;
      final payload = formData.fields
          .firstWhere((field) => field.key == 'payload')
          .value;
      _lastFeedbackPayload = jsonDecode(payload) as Map<String, dynamic>;
      return _jsonResponse({
        'data': {
          'id': 99,
          'status': 'RECEIVED',
          'createdAt': '2026-05-05T00:00:00Z',
          'screenshotAttached': formData.files.isNotEmpty,
        },
      }, statusCode: 201);
    }
    return _jsonResponse({'data': null}, statusCode: 404);
  }
}

Map<String, dynamic> _remoteSettingsPayload = {..._defaultRemoteSettings()};
Map<String, dynamic> _remoteAccessibilityPayload = {
  ..._defaultRemoteAccessibility(),
};
Map<String, dynamic>? _lastFeedbackPayload;
bool _feedbackShouldFail = false;

Finder _feedbackTextField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Map<String, dynamic> _defaultRemoteSettings() => {
  'privateJournal': true,
  'hideSocialCheckIns': true,
  'allowHistoryInsights': true,
  'useEmotionalDataForAi': true,
  'dailyReminders': true,
  'contentPreferences': true,
  'aiTone': 'acolhedor',
  'suggestionFrequency': 'equilibrada',
  'trailStyle': 'guiada',
};

Map<String, dynamic> _defaultRemoteAccessibility() => {
  'themeMode': 'dark',
  'highContrast': false,
  'reduceTransparency': false,
  'animationLevel': 'normal',
  'textSize': 'normal',
  'readingSpacing': 'comfortable',
  'accessibleFont': false,
  'focusMode': false,
  'reduceMotion': false,
  'hapticFeedback': true,
  'extendedResponseTime': false,
  'simplifiedNavigation': false,
  'reduceVisualStimuli': false,
  'softerLanguage': false,
  'hideSensitiveContent': false,
  'comfortMode': false,
};

class _FakeAuthAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _jsonResponse({'data': null});
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> exchangeGoogleCode({required String code}) async {
    return _testSession();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _testSession(email: email);
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getMe() async {
    return Profile(
      id: 1,
      userId: 'user-123',
      displayName: 'Leo Respiro',
      bio: '',
      journeyLevel: 1,
      premium: false,
      birthDate: DateTime(2000, 1, 1),
      gender: 'MALE',
      customGender: null,
      avatarUrl: null,
      createdAt: DateTime(2026, 1, 1),
    );
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

class _FakeSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<List<PlanView>> listPlans() async {
    return const [
      PlanView(
        planCode: 'essential-free',
        title: 'Essencial',
        subtitle: 'Base gratuita do app.',
        billingCycle: 'MONTHLY',
        premium: false,
        price: 0,
        currency: 'BRL',
        benefits: ['Base gratuita'],
        active: true,
      ),
      PlanView(
        planCode: 'premium-monthly',
        title: 'Premium',
        subtitle: 'Mais IA e jornadas premium.',
        billingCycle: 'MONTHLY',
        premium: true,
        price: 29.9,
        currency: 'BRL',
        benefits: ['Mais analises por dia'],
        active: true,
      ),
    ];
  }

  @override
  Future<CurrentSubscription?> current() async {
    return const CurrentSubscription(
      planCode: 'essential-free',
      status: 'ACTIVE',
      billingCycle: 'MONTHLY',
      premium: false,
      adsEnabled: true,
      aiQuotaRemainingToday: 1,
    );
  }

  @override
  Future<CurrentSubscription?> cancel() async => current();

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) async {
    return const CheckoutSession(
      id: 'checkout-1',
      planCode: 'premium-monthly',
      billingCycle: 'MONTHLY',
      status: 'PENDING',
      premium: true,
    );
  }

  @override
  Future<AdRewardSession> createRewardSession({required String rewardType}) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) async {
    return CheckoutSession(
      id: 'checkout-1',
      planCode: planCode,
      billingCycle: 'MONTHLY',
      status: 'PENDING',
      premium: true,
    );
  }
}

AuthSession _testSession({String email = 'leo@evolua.local'}) {
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
