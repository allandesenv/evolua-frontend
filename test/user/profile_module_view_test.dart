import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:evolua_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/content_module_view.dart';
import 'package:evolua_frontend/features/daily_ritual/application/daily_ritual_controller.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/future_message/application/future_message_controller.dart';
import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';
import 'package:evolua_frontend/features/future_message/domain/repositories/future_message_repository.dart';
import 'package:evolua_frontend/features/home/presentation/widgets/dashboard_shell.dart';
import 'package:evolua_frontend/features/notification/application/notification_controller.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';
import 'package:evolua_frontend/features/social/application/community_controller.dart';
import 'package:evolua_frontend/features/social/application/social_post_controller.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/community_repository.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';
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
import 'package:go_router/go_router.dart';
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
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
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
    expect(find.text('Planos e assinaturas'), findsNothing);
    expect(find.textContaining('Você está no plano Essencial'), findsNothing);
  });

  testWidgets('profile preferences navigation is hidden on mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProfileModuleView(section: ProfileModuleSection.overview),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Conta'), findsNothing);
    expect(find.text('Preferencias'), findsNothing);
    expect(find.text('Apoio'), findsNothing);
    expect(find.text('Configurações e privacidade'), findsNothing);
    expect(find.text('Ajuda e suporte'), findsNothing);
    expect(find.text('Tela e acessibilidade'), findsNothing);
    expect(find.text('Dar feedback'), findsNothing);
    expect(find.text('Planos e assinaturas'), findsNothing);
    expect(find.text('Leo Respiro'), findsOneWidget);
  });

  testWidgets('profile mobile renders externally selected section directly', (
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
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
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

    expect(find.text('Preferencias'), findsNothing);
    expect(find.text('Configurações e privacidade'), findsAtLeastNWidgets(1));
    expect(find.text('Conta e acesso'), findsOneWidget);
  });

  testWidgets('avatar menu exposes profile preference sections on mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    await _openAvatarMenu(tester);
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsAtLeastNWidgets(1));
    expect(find.text('Planos e assinaturas'), findsOneWidget);
    expect(find.text('Espelho da Evolução'), findsOneWidget);
    expect(find.text('Mensagens para o futuro'), findsOneWidget);
    expect(find.text('Configurações e privacidade'), findsOneWidget);
    expect(find.text('Ajuda e suporte'), findsOneWidget);
    expect(find.text('Tela e acessibilidade'), findsOneWidget);
    expect(find.text('Dar feedback'), findsOneWidget);

    final settingsTop = tester
        .getTopLeft(find.textContaining('privacidade'))
        .dy;
    final plansTop = tester.getTopLeft(find.text('Planos e assinaturas')).dy;
    final mirrorTop = tester
        .getTopLeft(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data?.startsWith('Espelho da ') ?? false),
          ),
        )
        .dy;

    expect(plansTop, greaterThan(settingsTop));
    expect(mirrorTop, greaterThan(plansTop));
  });

  testWidgets(
    'dashboard opens initial check-in prompt once per day on mobile',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'evolua.auth.session': jsonEncode(_testSession().toJson()),
      });
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _dashboardShell(checkInRepository: const _FakeCheckInRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Agora não'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Agora não'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Agora não'), findsNothing);

      await tester.pumpWidget(
        _dashboardShell(checkInRepository: const _FakeCheckInRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Agora não'), findsNothing);
    },
  );

  testWidgets('dashboard uses Início copy in navigation', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell(size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsAtLeastNWidgets(1));
    expect(find.text('Espelho'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(
      find.widgetWithText(NavigationDestination, 'Mentor Evolua'),
      findsNothing,
    );
  });

  testWidgets('admin sees admin panel in desktop sidebar and opens pages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(
        _testSession(roles: const ['ROLE_USER', 'ROLE_ADMIN']).toJson(),
      ),
    });
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell(size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    expect(find.text('Painel Admin'), findsOneWidget);
    expect(find.text('Trilhas'), findsWidgets);

    await tester.tap(find.text('Painel Admin'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Gerencie conteúdos e comunicações operacionais do Evolua em telas separadas.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Trilhas').last);
    await tester.pumpAndSettle();
    expect(find.text('Admin de trilhas'), findsAtLeastNWidgets(1));
    expect(find.text('Criar nova trilha'), findsOneWidget);

    await tester.tap(find.text('Notificações'));
    await tester.pumpAndSettle();
    expect(find.text('Central admin de notificações'), findsOneWidget);
  });

  testWidgets('non-admin does not see admin panel entry', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell(size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    expect(find.text('Painel Admin'), findsNothing);
  });

  testWidgets('mobile bottom bar does not include admin item', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(
        _testSession(roles: const ['ROLE_USER', 'ROLE_ADMIN']).toJson(),
      ),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    final navigationBar = find.byType(NavigationBar);
    expect(navigationBar, findsOneWidget);
    expect(
      find.descendant(of: navigationBar, matching: find.text('Painel Admin')),
      findsNothing,
    );

    await _openAvatarMenu(tester);
    await tester.pumpAndSettle();
    expect(find.text('Painel Admin'), findsOneWidget);
  });

  testWidgets('dashboard mobile back walks internal history to Início', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    expect(find.text('Como anda meu ritmo?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Trilhas'));
    await tester.pumpAndSettle();
    expect(find.byType(ContentModuleView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Espaços'));
    await tester.pumpAndSettle();
    expect(find.text('Em destaque'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Espelho'));
    await tester.pumpAndSettle();
    expect(find.text('Como eu estou evoluindo?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Em destaque'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ContentModuleView), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Como anda meu ritmo?'), findsOneWidget);
  });

  testWidgets('dashboard mobile ignores swipe between bottom tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    expect(find.text('Como anda meu ritmo?'), findsOneWidget);

    await _swipeDashboard(tester, -520);
    expect(find.text('Como anda meu ritmo?'), findsOneWidget);
    expect(find.byType(ContentModuleView), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Trilhas'));
    await tester.pumpAndSettle();
    expect(find.byType(ContentModuleView), findsOneWidget);

    await _swipeDashboard(tester, -520);
    expect(find.byType(ContentModuleView), findsOneWidget);
    expect(find.text('Em destaque'), findsNothing);
  });

  testWidgets('dashboard mobile back respects bottom navigation history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Trilhas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Espaços'));
    await tester.pumpAndSettle();
    expect(find.text('Em destaque'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ContentModuleView), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Como anda meu ritmo?'), findsOneWidget);
  });

  testWidgets('dashboard mobile swipe ignores hidden internal sections', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final trail = _testTrail();

    await tester.pumpWidget(
      _dashboardShell(
        trailRepository: _FakeTrailRepository(
          currentJourney: trail,
          journey: _testJourney(trail),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openAvatarMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Trocar foto'), findsOneWidget);
    await _swipeDashboard(tester, -520);
    expect(find.widgetWithText(OutlinedButton, 'Trocar foto'), findsOneWidget);
    expect(find.byType(ContentModuleView), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Trilhas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir Mentor Evolua'));
    await tester.tap(find.text('Abrir Mentor Evolua'));
    await tester.pumpAndSettle();

    expect(find.text('Mentor Evolua'), findsAtLeastNWidgets(1));
    await _swipeDashboard(tester, 520);
    expect(find.text('Mentor Evolua'), findsAtLeastNWidgets(1));
    expect(find.text('Em destaque'), findsNothing);
  });

  testWidgets('dashboard desktop ignores horizontal swipe gestures', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell(size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    expect(find.text('Como anda meu ritmo?'), findsOneWidget);

    await _swipeDashboard(tester, -520);

    expect(find.text('Como anda meu ritmo?'), findsOneWidget);
    expect(find.byType(ContentModuleView), findsNothing);
  });

  testWidgets('avatar menu opens future messages route', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShellWithFutureMessagesRoute());
    await tester.pumpAndSettle();

    await _openAvatarMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mensagens para o futuro'));
    await tester.pumpAndSettle();

    expect(find.text('Future messages route'), findsOneWidget);
  });

  testWidgets('reflections card opens future messages route with new title', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShellWithFutureMessagesRoute());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Espaços'));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Em destaque'), findsOneWidget);
    expect(find.text('Reflexoes'), findsOneWidget);
    expect(find.text('Meus'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Meus espacos'), findsNothing);

    await tester.tap(find.text('Reflexoes'));
    await tester.pumpAndSettle();

    expect(find.text('Mensagens para o futuro'), findsOneWidget);
    expect(find.text('Mensagens do seu eu anterior'), findsNothing);

    await tester.ensureVisible(find.text('Abrir mensagens'));
    await tester.tap(find.text('Abrir mensagens'));
    await tester.pumpAndSettle();

    expect(find.text('Future messages route'), findsOneWidget);
  });

  testWidgets('spaces button switcher opens Meus area', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Espaços'));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsNothing);
    await tester.tap(find.text('Meus'));
    await tester.pumpAndSettle();

    expect(find.text('Meus espacos'), findsOneWidget);
    expect(find.text('0 participando'), findsAtLeastNWidgets(1));
    expect(find.text('Em destaque'), findsOneWidget);
    expect(find.text('Reflexoes'), findsOneWidget);
  });

  testWidgets('journey CTA still opens mentor after removing nav item', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final trail = _testTrail();

    await tester.pumpWidget(
      _dashboardShell(
        trailRepository: _FakeTrailRepository(
          currentJourney: trail,
          journey: _testJourney(trail),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Trilhas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abrir Mentor Evolua'));
    await tester.tap(find.text('Abrir Mentor Evolua'));
    await tester.pumpAndSettle();

    expect(find.text('Mentor Evolua'), findsAtLeastNWidgets(1));
    expect(
      find.widgetWithText(NavigationDestination, 'Mentor Evolua'),
      findsNothing,
    );
  });

  testWidgets('avatar menu opens plans and overview sections', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    await _openAvatarMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planos e assinaturas'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Você está no plano Essencial'), findsOneWidget);

    await _openAvatarMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Trocar foto'), findsOneWidget);
    expect(find.textContaining('Você está no plano Essencial'), findsNothing);
  });

  testWidgets('avatar menu opens evolution mirror section', (tester) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dashboardShell());
    await tester.pumpAndSettle();

    await _openAvatarMenu(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espelho da Evolução'));
    await tester.pumpAndSettle();

    expect(find.text('Espelho da Evolução'), findsAtLeastNWidgets(1));
    expect(find.text('Como eu estou evoluindo?'), findsOneWidget);
    expect(find.text('Resumo da semana'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Trocar foto'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Atualizar'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Como anda meu ritmo?'), findsOneWidget);
  });

  testWidgets('profile preferences render sidebar on expanded desktop', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const MediaQuery(
            data: MediaQueryData(size: Size(1280, 900)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ProfileModuleView(
                  section: ProfileModuleSection.settingsPrivacy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 288,
      ),
      findsOneWidget,
    );
    expect(find.text('Leo Respiro'), findsOneWidget);
    expect(find.text('Configurações e privacidade'), findsAtLeastNWidgets(1));
    expect(find.text('Conta e acesso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile preferences follow externally selected section', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    final selectedSection = ValueNotifier(ProfileModuleSection.feedback);
    addTearDown(selectedSection.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<ProfileModuleSection>(
                valueListenable: selectedSection,
                builder: (context, section, _) {
                  return ProfileModuleView(section: section);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compartilhe sua experiência'), findsOneWidget);

    selectedSection.value = ProfileModuleSection.plansSubscriptions;
    await tester.pumpAndSettle();

    expect(find.textContaining('Você está no plano Essencial'), findsOneWidget);
    expect(find.text('Compartilhe sua experiência'), findsNothing);
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
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
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

    expect(find.text('Configurações e privacidade'), findsAtLeastNWidgets(1));
    expect(find.text('Conta e acesso'), findsOneWidget);
    expect(find.text('Privacidade emocional'), findsOneWidget);
    expect(find.text('Dados e segurança'), findsOneWidget);
    expect(find.text('Personalização da experiência'), findsOneWidget);
    expect(find.text('E-mail de acesso'), findsOneWidget);
    expect(find.text('leo@evolua.local'), findsAtLeastNWidgets(1));
    expect(find.text('Tornar diario privado'), findsOneWidget);
    expect(find.text('Baixar meus dados'), findsAtLeastNWidgets(1));
    expect(find.text('Tom da IA'), findsOneWidget);

    await tester.ensureVisible(find.text('Salvar preferencias'));
    await tester.tap(find.text('Salvar preferencias'));
    await tester.pumpAndSettle();

    expect(find.text('Preferências salvas com segurança.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders evolution mirror with empty data safely', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });

    await _pumpEvolutionMirror(tester, premium: true);

    expect(find.text('Espelho da Evolução'), findsAtLeastNWidgets(1));
    expect(find.text('Como eu estou evoluindo?'), findsOneWidget);
    expect(find.text('Resumo da semana'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Trocar foto'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Atualizar'), findsNothing);
    expect(find.text('Padroes percebidos'), findsOneWidget);
    expect(find.text('Mensagem da IA'), findsOneWidget);
    expect(find.text('Mensagens do seu eu anterior'), findsNothing);
    expect(find.text('Trilhas em andamento'), findsOneWidget);
    expect(find.text('Marcos da jornada'), findsOneWidget);
    expect(find.text('Consistência'), findsAtLeastNWidgets(1));
    expect(find.text('sem padrão ainda'), findsOneWidget);
    expect(find.text('em formação'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders evolution mirror with journey and insight data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    final trail = _testTrail();

    await _pumpEvolutionMirror(
      tester,
      premium: true,
      trailRepository: _FakeTrailRepository(
        currentJourney: trail,
        journey: _testJourney(trail),
      ),
      checkInRepository: _FakeCheckInRepository(items: _evolutionCheckIns()),
    );

    expect(find.text('Clareza pratica'), findsAtLeastNWidgets(1));
    expect(find.textContaining('50% concluído'), findsOneWidget);
    expect(find.text('Próximo passo: Escolher'), findsOneWidget);
    expect(find.text('Mensagem da IA'), findsOneWidget);
    expect(
      find.text('Você tende a registrar mais ansiedade à noite.'),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('1 padrão emocional identificado'), findsOneWidget);
    expect(find.text('3 dias de check-in'), findsOneWidget);
    expect(
      find.text('Próximo passo: Escolha uma proxima acao simples.'),
      findsOneWidget,
    );
    expect(find.text('Ansioso'), findsOneWidget);
  });

  testWidgets('renders previous-self messages in mirror only when delivered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });

    await _pumpEvolutionMirror(
      tester,
      premium: true,
      checkInRepository: _FakeCheckInRepository(items: _evolutionCheckIns()),
      futureMessageRepository: _FakeFutureMessageRepository(
        deliveredItems: [_deliveredFutureMessage()],
      ),
    );

    expect(find.text('Mensagens do seu eu anterior'), findsOneWidget);
    expect(
      find.text('Há uma carta sua pronta para ser lida com calma.'),
      findsOneWidget,
    );
    expect(find.text('Quero ler'), findsOneWidget);
  });

  testWidgets('renders evolution mirror milestones with rich progress data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'evolua.auth.session': jsonEncode(_testSession().toJson()),
    });
    final trail = _testTrail();

    await _pumpEvolutionMirror(
      tester,
      premium: true,
      trailRepository: _FakeTrailRepository(
        currentJourney: trail,
        journey: _testCompletedJourney(trail),
      ),
      checkInRepository: _FakeCheckInRepository(
        items: _evolutionRichCheckIns(),
      ),
    );

    expect(find.textContaining('100% concluído'), findsOneWidget);
    expect(find.text('Primeira trilha concluída'), findsOneWidget);
    expect(find.text('7 reflexões registradas'), findsOneWidget);
    expect(find.text('1 padrão emocional identificado'), findsOneWidget);
    expect(
      find.text('Seus melhores dias aparecem quando faz check-in pela manha.'),
      findsAtLeastNWidgets(1),
    );
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
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
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
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
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
    expect(find.text('Compartilhe sua experiência'), findsOneWidget);
    expect(find.text('Sugerir melhoria'), findsOneWidget);
    expect(find.text('Reportar problema'), findsOneWidget);
    expect(find.text('Avaliação rápida'), findsOneWidget);
    expect(find.text('Enviar feedback'), findsOneWidget);

    await tester.enterText(
      _feedbackTextField('O que está funcionando bem?'),
      'As trilhas estão claras.',
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
    expect(_lastFeedbackPayload?['workingWell'], 'As trilhas estão claras.');
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
          authSessionStorageProvider.overrideWithValue(
            _SharedPreferencesAuthSessionStorage(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            _FakeSubscriptionRepository(),
          ),
          authenticatedDioProvider(
            AppConfig.userBaseUrl,
          ).overrideWithValue(_fakeUserDio()),
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
    expect(find.text('Navegação e interação'), findsOneWidget);
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
      find.text('Preferências visuais salvas com conforto.'),
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
        authSessionStorageProvider.overrideWithValue(
          _SharedPreferencesAuthSessionStorage(),
        ),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        subscriptionRepositoryProvider.overrideWithValue(
          _FakeSubscriptionRepository(),
        ),
        authenticatedDioProvider(
          AppConfig.userBaseUrl,
        ).overrideWithValue(_fakeUserDio()),
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
        authSessionStorageProvider.overrideWithValue(
          _SharedPreferencesAuthSessionStorage(),
        ),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        subscriptionRepositoryProvider.overrideWithValue(
          _FakeSubscriptionRepository(),
        ),
        authenticatedDioProvider(
          AppConfig.userBaseUrl,
        ).overrideWithValue(_fakeUserDio()),
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

Future<void> _pumpEvolutionMirror(
  WidgetTester tester, {
  TrailRepository? trailRepository,
  CheckInRepository? checkInRepository,
  FutureMessageRepository? futureMessageRepository,
  bool premium = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        authSessionStorageProvider.overrideWithValue(
          _SharedPreferencesAuthSessionStorage(),
        ),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        subscriptionRepositoryProvider.overrideWithValue(
          _FakeSubscriptionRepository(premium: premium),
        ),
        trailRepositoryProvider.overrideWithValue(
          trailRepository ?? _FakeTrailRepository(),
        ),
        checkInRepositoryProvider.overrideWithValue(
          checkInRepository ?? _FakeCheckInRepository(),
        ),
        futureMessageRepositoryProvider.overrideWithValue(
          futureMessageRepository ?? _FakeFutureMessageRepository(),
        ),
        authenticatedDioProvider(
          AppConfig.userBaseUrl,
        ).overrideWithValue(_fakeUserDio()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ProfileModuleView(
              section: ProfileModuleSection.evolutionMirror,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _dashboardShell({
  Size size = const Size(390, 900),
  TrailRepository? trailRepository,
  CheckInRepository? checkInRepository,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      authSessionStorageProvider.overrideWithValue(
        _SharedPreferencesAuthSessionStorage(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      subscriptionRepositoryProvider.overrideWithValue(
        _FakeSubscriptionRepository(),
      ),
      trailRepositoryProvider.overrideWithValue(
        trailRepository ?? _FakeTrailRepository(),
      ),
      checkInRepositoryProvider.overrideWithValue(
        checkInRepository ?? _FakeCheckInRepository(items: [_todayCheckIn()]),
      ),
      socialPostRepositoryProvider.overrideWithValue(
        _FakeSocialPostRepository(),
      ),
      communityRepositoryProvider.overrideWithValue(_FakeCommunityRepository()),
      notificationRepositoryProvider.overrideWithValue(
        _FakeNotificationRepository(),
      ),
      futureMessageRepositoryProvider.overrideWithValue(
        _FakeFutureMessageRepository(),
      ),
      dailyRitualRepositoryProvider.overrideWithValue(
        const _FakeDailyRitualRepository(),
      ),
      authenticatedDioProvider(
        AppConfig.userBaseUrl,
      ).overrideWithValue(_fakeUserDio()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const Scaffold(body: DashboardShell()),
      ),
    ),
  );
}

Widget _dashboardShellWithFutureMessagesRoute() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MediaQuery(
          data: MediaQueryData(size: Size(390, 900)),
          child: Scaffold(body: DashboardShell()),
        ),
      ),
      GoRoute(
        path: '/future-messages',
        builder: (context, state) =>
            const Scaffold(body: Text('Future messages route')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      authSessionStorageProvider.overrideWithValue(
        _SharedPreferencesAuthSessionStorage(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      subscriptionRepositoryProvider.overrideWithValue(
        _FakeSubscriptionRepository(),
      ),
      trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
      checkInRepositoryProvider.overrideWithValue(
        _FakeCheckInRepository(items: [_todayCheckIn()]),
      ),
      socialPostRepositoryProvider.overrideWithValue(
        _FakeSocialPostRepository(),
      ),
      communityRepositoryProvider.overrideWithValue(_FakeCommunityRepository()),
      notificationRepositoryProvider.overrideWithValue(
        _FakeNotificationRepository(),
      ),
      futureMessageRepositoryProvider.overrideWithValue(
        _FakeFutureMessageRepository(),
      ),
      dailyRitualRepositoryProvider.overrideWithValue(
        const _FakeDailyRitualRepository(),
      ),
      authenticatedDioProvider(
        AppConfig.userBaseUrl,
      ).overrideWithValue(_fakeUserDio()),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

Future<void> _openAvatarMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Abrir menu da conta'));
}

Future<void> _swipeDashboard(
  WidgetTester tester,
  double horizontalOffset,
) async {
  await tester.fling(
    find.byType(DashboardShell),
    Offset(horizontalOffset, 0),
    1200,
  );
  await tester.pumpAndSettle();
}

Dio _fakeUserDio() {
  return Dio()..httpClientAdapter = _FakeUserAdapter();
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
            'label': 'Notificações',
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
    if (options.path.startsWith('/v1/auth/me')) {
      return _jsonResponse({'data': null});
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

Trail _testTrail() {
  return Trail(
    id: 7,
    userId: 'user-123',
    title: 'Clareza pratica',
    summary: 'Uma trilha ativa para organizar o momento.',
    content: 'Conteudo da trilha.',
    category: 'foco',
    premium: false,
    privateTrail: true,
    activeJourney: true,
    generatedByAi: true,
    journeyKey: 'clareza-pratica',
    sourceStyle: 'briefing',
    accessible: true,
    mediaLinks: const [],
    steps: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

TrailJourney _testJourney(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      summary: 'Dois minutos de presenca.',
      content: 'Respire por quatro ciclos.',
      type: 'EXERCISE',
      status: 'completed',
      estimatedMinutes: 2,
      mediaLinks: [],
    ),
    const TrailJourneyStep(
      index: 1,
      title: 'Escolher',
      summary: 'Uma proxima acao simples.',
      content: 'Escolha uma acao pequena.',
      type: 'REFLECTION',
      status: 'current',
      estimatedMinutes: 4,
      mediaLinks: [],
    ),
  ];
  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 1,
      completedStepIndexes: const [0],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      completedAt: null,
    ),
    progressPercent: 50,
    nextStep: steps.last,
  );
}

FutureMessage _deliveredFutureMessage() {
  return FutureMessage(
    id: 88,
    title: 'Carta para mim mesmo',
    body: 'Lembre que voce ja atravessou dias assim antes.',
    bodyPreview: 'Lembre que voce ja atravessou dias assim antes.',
    triggerType: 'LOW_ENERGY_CHECKIN',
    triggerConfig: const {'energyMax': 3},
    triggerLabel: 'Quando a energia estiver baixa',
    status: 'DELIVERED',
    createdContext: const {'mood': 'ansioso', 'energyLevel': 4},
    deliveredContext: const {'mood': 'cansado', 'energyLevel': 2},
    createdAt: DateTime(2026, 1, 1),
    scheduledFor: null,
    deliveredAt: DateTime(2026, 1, 30),
  );
}

TrailJourney _testCompletedJourney(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      summary: 'Dois minutos de presenca.',
      content: 'Respire por quatro ciclos.',
      type: 'EXERCISE',
      status: 'completed',
      estimatedMinutes: 2,
      mediaLinks: [],
    ),
    const TrailJourneyStep(
      index: 1,
      title: 'Escolher',
      summary: 'Uma proxima acao simples.',
      content: 'Escolha uma acao pequena.',
      type: 'REFLECTION',
      status: 'completed',
      estimatedMinutes: 4,
      mediaLinks: [],
    ),
  ];
  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 1,
      completedStepIndexes: const [0, 1],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 3),
      completedAt: DateTime(2026, 1, 3),
    ),
    progressPercent: 100,
    nextStep: null,
  );
}

List<CheckIn> _evolutionCheckIns() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    CheckIn(
      id: 1,
      userId: 'user-123',
      mood: 'ansioso',
      reflection: 'Dia intenso.',
      energyLevel: 6,
      recommendedPractice: 'Respire por dois minutos.',
      aiInsight: const CheckInAiInsight(
        insight: 'Seu check-in mostra uma busca por clareza.',
        suggestedAction: 'Escolha uma proxima acao simples.',
        riskLevel: 'low',
        suggestedTrailId: 7,
        suggestedTrailTitle: 'Clareza pratica',
        suggestedTrailReason: 'Combina com o momento atual.',
        suggestedSpace: null,
        journeyPlan: null,
        generatedTrailDraft: null,
        fallbackUsed: false,
      ),
      createdAt: today.add(const Duration(hours: 21)),
    ),
    CheckIn(
      id: 2,
      userId: 'user-123',
      mood: 'ansioso',
      reflection: 'Ansiedade voltou no fim do dia.',
      energyLevel: 5,
      recommendedPractice: 'Pausa curta antes de dormir.',
      aiInsight: null,
      createdAt: today
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 22)),
    ),
    CheckIn(
      id: 3,
      userId: 'user-123',
      mood: 'calmo',
      reflection: 'Manha mais clara.',
      energyLevel: 8,
      recommendedPractice: 'Caminhada curta.',
      aiInsight: null,
      createdAt: today
          .subtract(const Duration(days: 2))
          .add(const Duration(hours: 8)),
    ),
  ];
}

CheckIn _todayCheckIn() {
  return CheckIn(
    id: 999,
    userId: 'user-123',
    mood: 'calmo',
    reflection: '',
    energyLevel: 7,
    recommendedPractice: 'Respire por alguns minutos.',
    aiInsight: null,
    createdAt: DateTime.now(),
  );
}

List<CheckIn> _evolutionRichCheckIns() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final moods = [
    'calmo',
    'confiante',
    'calmo',
    'criativo',
    'ansioso',
    'calmo',
    'grato',
  ];
  final energies = [9, 8, 8, 9, 5, 7, 8];
  return List.generate(7, (index) {
    final day = today.subtract(Duration(days: index));
    return CheckIn(
      id: index + 10,
      userId: 'user-123',
      mood: moods[index],
      reflection: 'Reflexao registrada ${index + 1}.',
      energyLevel: energies[index],
      recommendedPractice: 'Pratica curta.',
      aiInsight: index == 0
          ? const CheckInAiInsight(
              insight: 'Voce esta percebendo melhor seus ritmos.',
              suggestedAction: 'Mantenha o check-in pela manha.',
              riskLevel: 'low',
              suggestedTrailId: 7,
              suggestedTrailTitle: 'Clareza pratica',
              suggestedTrailReason: 'Ajuda a manter constancia.',
              suggestedSpace: null,
              journeyPlan: null,
              generatedTrailDraft: null,
              fallbackUsed: false,
            )
          : null,
      createdAt: day.add(Duration(hours: index < 3 ? 8 : 17)),
    );
  });
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

class _SharedPreferencesAuthSessionStorage implements AuthSessionStorage {
  static const _key = 'evolua.auth.session';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
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
  Future<AuthSession> refresh({required String refreshToken}) async {
    return _testSession();
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
  _FakeSubscriptionRepository({this.premium = false});

  final bool premium;

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
    return CurrentSubscription(
      planCode: premium ? 'premium-monthly' : 'essential-free',
      status: 'ACTIVE',
      billingCycle: 'MONTHLY',
      premium: premium,
      adsEnabled: !premium,
      aiQuotaRemainingToday: premium ? 20 : 1,
      mentorPremiumPassActive: false,
      mentorRewardedAdAvailable: false,
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
  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  }) async {
    return CheckoutSession(
      id: 'checkout-google-play',
      planCode: planCode,
      billingCycle: 'MONTHLY',
      status: 'APPROVED',
      premium: true,
    );
  }

  @override
  Future<AdRewardSession> createRewardSession({
    required String rewardType,
    String? contextId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
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

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) async {
    return MonetizationAccessStatus(
      resource: resource,
      contextId: contextId,
      allowed: false,
      premium: false,
      rewardedAdAvailable: true,
      upgradeRecommended: true,
      limitMessage: null,
    );
  }
}

class _FakeTrailRepository implements TrailRepository {
  const _FakeTrailRepository({Trail? currentJourney, TrailJourney? journey})
    : _currentJourney = currentJourney,
      _journey = journey;

  final Trail? _currentJourney;
  final TrailJourney? _journey;

  @override
  Future<PaginatedResponse<Trail>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  }) async {
    final items = _currentJourney == null ? const <Trail>[] : [_currentJourney];
    return PaginatedResponse<Trail>(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<Trail?> currentJourney() async => _currentJourney;

  @override
  Future<Trail> create({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> journey(int trailId) async {
    final journey = _journey;
    if (journey == null) {
      throw StateError('Sem jornada ativa.');
    }
    return journey;
  }

  @override
  Future<TrailJourney> startJourney(int trailId) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) {
    throw UnimplementedError();
  }

  @override
  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Trail> update({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCheckInRepository implements CheckInRepository {
  const _FakeCheckInRepository({this.items = const <CheckIn>[]});

  final List<CheckIn> items;

  @override
  Future<PaginatedResponse<CheckIn>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? mood,
    String? energyRange,
    DateTime? from,
    DateTime? to,
  }) async {
    return PaginatedResponse<CheckIn>(
      items: items,
      page: page,
      size: size,
      totalItems: items.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<CheckIn> create({
    required String mood,
    String? reflection,
    required int energyLevel,
  }) async {
    return CheckIn(
      id: 1,
      userId: 'user-123',
      mood: mood,
      reflection: reflection ?? '',
      energyLevel: energyLevel,
      recommendedPractice: 'Respire por alguns minutos.',
      aiInsight: null,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<CheckIn> generateDeepReading(int checkInId) async {
    return items.firstWhere(
      (item) => item.id == checkInId,
      orElse: () => CheckIn(
        id: checkInId,
        userId: 'user-123',
        mood: 'calmo',
        reflection: '',
        energyLevel: 7,
        recommendedPractice: 'Respire por alguns minutos.',
        aiInsight: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }
}

class _FakeFutureMessageRepository implements FutureMessageRepository {
  const _FakeFutureMessageRepository({
    this.deliveredItems = const <FutureMessage>[],
  });

  final List<FutureMessage> deliveredItems;

  @override
  Future<PaginatedResponse<FutureMessage>> list({
    required int page,
    required int size,
    List<String>? statuses,
  }) async {
    return PaginatedResponse<FutureMessage>.empty(page: page, size: size);
  }

  @override
  Future<PaginatedResponse<FutureMessage>> delivered({
    required int page,
    required int size,
  }) async {
    return PaginatedResponse<FutureMessage>(
      items: deliveredItems,
      page: page,
      size: size,
      totalItems: deliveredItems.length,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: 'deliveredAt',
      sortDir: 'desc',
      filters: const {},
    );
  }

  @override
  Future<FutureMessage> create(FutureMessageDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> get(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> heartbeat() async {}

  @override
  Future<FutureMessage> markRead(int id) {
    throw UnimplementedError();
  }

  @override
  Future<FutureMessage> react(int id, String reaction) {
    throw UnimplementedError();
  }
}

class _FakeDailyRitualRepository implements DailyRitualRepository {
  const _FakeDailyRitualRepository();

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    return null;
  }

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) {
    throw UnimplementedError();
  }
}

class _FakeSocialPostRepository implements SocialPostRepository {
  @override
  Future<PaginatedResponse<SocialPost>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? community,
    String? visibility,
    bool? mine,
  }) async {
    return PaginatedResponse<SocialPost>.empty(page: page, size: size);
  }

  @override
  Future<SocialPost> create({
    required String content,
    required String community,
    required String visibility,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCommunityRepository implements CommunityRepository {
  @override
  Future<PaginatedResponse<Community>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? visibility,
    String? category,
    bool? joined,
  }) async {
    return PaginatedResponse<Community>.empty(page: page, size: size);
  }

  @override
  Future<Community> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Community> join(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Community> leave(String id) {
    throw UnimplementedError();
  }
}

class _FakeNotificationRepository implements NotificationRepository {
  @override
  Future<List<NotificationJob>> list({bool unreadOnly = false}) async =>
      const [];

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<NotificationJob> createAdmin({
    required String targetUserId,
    required String type,
    required String title,
    required String message,
    String? actionTarget,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<NotificationJob> markAsRead(String id) {
    throw UnimplementedError();
  }

  @override
  Future<int> markAllAsRead() async => 0;
}

AuthSession _testSession({
  String email = 'leo@evolua.local',
  List<String> roles = const ['ROLE_USER'],
}) {
  return AuthSession(
    userId: 'user-123',
    email: email,
    roles: roles,
    accessToken: _buildJwt(
      sub: 'user-123',
      email: email,
      roles: roles,
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
