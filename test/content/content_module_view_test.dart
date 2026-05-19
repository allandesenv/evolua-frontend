import 'dart:typed_data';

import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/core/theme/evolua_theme_colors.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_progress.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/content_module_view.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:evolua_frontend/features/user/application/profile_controller.dart';
import 'package:evolua_frontend/features/user/domain/entities/profile.dart';
import 'package:evolua_frontend/features/user/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ContentModuleView mobile trails navigation', () {
    testWidgets('shows journey and catalog switcher on compact width', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Minha jornada'), findsOneWidget);
      expect(find.text('Explorar'), findsOneWidget);
      expect(find.text('Explorar trilhas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens catalog even when an active journey exists', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();

      expect(find.text('Encontrar uma trilha certa'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(find.text('Minha jornada ativa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens catalog from active journey action', (tester) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explorar trilhas'));
      await tester.pumpAndSettle();

      expect(find.text('Encontrar uma trilha certa'), findsOneWidget);
      expect(find.text('Respiracao breve'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses light surfaces and readable text in light theme', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(theme: AppTheme.light(accessibleFont: true)),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Minha jornada'));
      final colors = context.evoluaColors;
      final panel = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = panel.decoration! as BoxDecoration;

      expect(Theme.of(context).brightness, Brightness.light);
      expect(decoration.color, colors.surface.withValues(alpha: 0.94));
      expect(
        decoration.color,
        isNot(AppColors.surface.withValues(alpha: 0.94)),
      );
      expect(
        Theme.of(context).textTheme.bodyMedium?.color,
        isNot(AppColors.textSecondary),
      );
    });

    testWidgets('locked mentor premium trail offers Premium-only details', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      var premiumOpened = false;

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: _FakeTrailRepository(
            catalogTrail: _trail(
              id: 7,
              title: 'Mentoria para destravar a jornada',
              summary: 'Uma trilha de mentoria para clarear bloqueios.',
              activeJourney: false,
              generatedByAi: false,
              category: 'mentoria',
              premium: true,
              accessible: false,
              sourceStyle: 'mentor_exclusive',
            ),
          ),
          onOpenPremium: () => premiumOpened = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mentoria premium'), findsOneWidget);
      expect(find.text('Premium'), findsWidgets);

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();

      expect(find.text('Mentoria disponível no Premium'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(find.text('Aprofundar com Premium'), findsOneWidget);

      await tester.ensureVisible(find.text('Aprofundar com Premium'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprofundar com Premium'));
      await tester.pumpAndSettle();

      expect(premiumOpened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mentor premium trail does not use rewarded pass refresh', (
      tester,
    ) async {
      await _setCompactSurface(tester);
      final rewardedService = _FakeRewardedAdService();
      final subscriptionRepository = _FakeSubscriptionRepository(
        mentorPassActiveFromCall: 4,
      );
      final trailRepository = _FakeTrailRepository(
        catalogTrail: _trail(
          id: 8,
          title: 'Mentoria para destravar a jornada',
          summary: 'Uma trilha de mentoria para clarear bloqueios.',
          activeJourney: false,
          generatedByAi: false,
          category: 'mentoria',
          premium: true,
          accessible: false,
          sourceStyle: 'mentor_exclusive',
        ),
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
          subscriptionRepository: subscriptionRepository,
          rewardedAdService: rewardedService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Mentoria disponível no Premium'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(rewardedService.lastRewardType, isNull);
      expect(subscriptionRepository.currentCallCount, greaterThanOrEqualTo(1));
      expect(trailRepository.listCallCount, 1);
      expect(find.text('Continuar trilha'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mentor trail stays blocked without Premium', (tester) async {
      await _setCompactSurface(tester);
      final rewardedService = _FakeRewardedAdService();
      final subscriptionRepository = _FakeSubscriptionRepository();
      final trailRepository = _FakeTrailRepository(
        catalogTrail: _trail(
          id: 10,
          title: 'Mentoria para destravar a jornada',
          summary: 'Uma trilha de mentoria para clarear bloqueios.',
          activeJourney: false,
          generatedByAi: false,
          category: 'mentoria',
          premium: true,
          accessible: false,
          sourceStyle: 'mentor_exclusive',
        ),
      );

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: trailRepository,
          subscriptionRepository: subscriptionRepository,
          rewardedAdService: rewardedService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Mentoria disponível no Premium'), findsOneWidget);
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(rewardedService.lastRewardType, isNull);
      expect(find.text('Continuar trilha'), findsNothing);
      expect(trailRepository.listCallCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('regular premium trail keeps premium-only detail state', (
      tester,
    ) async {
      await _setCompactSurface(tester);

      await tester.pumpWidget(
        _testApp(
          section: ContentModuleSection.catalog,
          trailRepository: _FakeTrailRepository(
            catalogTrail: _trail(
              id: 9,
              title: 'Sono profundo premium',
              summary: 'Uma trilha premium fora da mentoria.',
              activeJourney: false,
              generatedByAi: false,
              category: 'sono',
              premium: true,
              accessible: false,
              sourceStyle: 'catalog',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esta trilha aprofunda sua evolução emocional'),
        findsOneWidget,
      );
      expect(find.text('Assistir anúncio'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _setCompactSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp({
  ThemeData? theme,
  ContentModuleSection section = ContentModuleSection.journey,
  TrailRepository? trailRepository,
  SubscriptionRepository? subscriptionRepository,
  RewardedAdService? rewardedAdService,
  VoidCallback? onOpenPremium,
}) {
  SharedPreferences.setMockInitialValues({});

  return ProviderScope(
    overrides: [
      trailRepositoryProvider.overrideWithValue(
        trailRepository ?? _FakeTrailRepository(),
      ),
      subscriptionRepositoryProvider.overrideWithValue(
        subscriptionRepository ?? _FakeSubscriptionRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      if (rewardedAdService != null)
        rewardedAdServiceProvider.overrideWithValue(rewardedAdService),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SizedBox.expand(
          child: ContentModuleView(
            section: section,
            showSectionChips: true,
            onOpenPremium: onOpenPremium,
          ),
        ),
      ),
    ),
  );
}

class _FakeTrailRepository implements TrailRepository {
  _FakeTrailRepository({Trail? activeTrail, Trail? catalogTrail})
    : _activeTrail =
          activeTrail ??
          _trail(
            id: 1,
            title: 'Clareza em 8 minutos',
            summary: 'Uma jornada ativa para organizar o momento.',
            activeJourney: true,
            generatedByAi: true,
          ),
      _catalogTrail =
          catalogTrail ??
          _trail(
            id: 2,
            title: 'Respiracao breve',
            summary: 'Uma trilha curta para voltar ao corpo.',
            activeJourney: false,
            generatedByAi: false,
          );

  final Trail _activeTrail;
  final Trail _catalogTrail;
  int listCallCount = 0;

  @override
  Future<Trail?> currentJourney() async => _activeTrail;

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
    listCallCount++;
    return PaginatedResponse(
      items: [_catalogTrail],
      page: page,
      size: size,
      totalItems: 1,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
  }

  @override
  Future<TrailJourney> journey(int trailId) async {
    final trail = trailId == _activeTrail.id ? _activeTrail : _catalogTrail;
    return _journey(trail);
  }

  @override
  Future<TrailJourney> startJourney(int trailId) async {
    return journey(trailId);
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) async {
    return journey(trailId);
  }

  @override
  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  }) async {
    return journey(trailId);
  }

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

class _FakeRewardedAdService implements RewardedAdService {
  String? lastRewardType;

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
  }) async {
    lastRewardType = rewardType;
    return true;
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({this.mentorPassActiveFromCall});

  final int? mentorPassActiveFromCall;
  int currentCallCount = 0;

  @override
  Future<CurrentSubscription?> current() async {
    currentCallCount++;
    final mentorPassActive =
        mentorPassActiveFromCall != null &&
        currentCallCount >= mentorPassActiveFromCall!;
    return CurrentSubscription(
      planCode: 'essential-free',
      status: 'ACTIVE',
      billingCycle: 'MONTHLY',
      premium: false,
      adsEnabled: true,
      aiQuotaRemainingToday: 1,
      mentorPremiumPassActive: mentorPassActive,
      mentorRewardedAdAvailable: !mentorPassActive,
      mentorPremiumPassEndsAt: mentorPassActive ? DateTime(2026, 5, 7) : null,
    );
  }

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<CurrentSubscription?> cancel() async => current();

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
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
    );
  }
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getMe() async => null;

  @override
  Future<Profile> upsertMe({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    String? customGender,
    required String bio,
    required int journeyLevel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) {
    throw UnimplementedError();
  }
}

Trail _trail({
  required int id,
  required String title,
  required String summary,
  required bool activeJourney,
  required bool generatedByAi,
  String category = 'clareza',
  bool premium = false,
  bool accessible = true,
  String? sourceStyle = 'briefing',
}) {
  return Trail(
    id: id,
    userId: 'user-123',
    title: title,
    summary: summary,
    content: 'Respire, nomeie e escolha.',
    category: category,
    premium: premium,
    privateTrail: false,
    activeJourney: activeJourney,
    generatedByAi: generatedByAi,
    journeyKey: 'clareza',
    sourceStyle: sourceStyle,
    accessible: accessible,
    mediaLinks: const [],
    steps: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

TrailJourney _journey(Trail trail) {
  final steps = [
    const TrailJourneyStep(
      index: 0,
      title: 'Respirar',
      summary: 'Dois minutos de presenca.',
      content: 'Respire por quatro ciclos.',
      type: 'EXERCISE',
      status: 'current',
      estimatedMinutes: 2,
      mediaLinks: [],
    ),
    const TrailJourneyStep(
      index: 1,
      title: 'Escolher',
      summary: 'Uma proxima acao simples.',
      content: 'Escolha uma acao pequena.',
      type: 'REFLECTION',
      status: 'pending',
      estimatedMinutes: 4,
      mediaLinks: [],
    ),
  ];

  return TrailJourney(
    trail: trail,
    steps: steps,
    progress: TrailProgress(
      currentStepIndex: 0,
      completedStepIndexes: const [],
      startedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      completedAt: null,
    ),
    progressPercent: 0,
    nextStep: steps.first,
  );
}
