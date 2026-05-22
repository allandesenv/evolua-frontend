import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_theme.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/emotional/application/check_in_controller.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';
import 'package:evolua_frontend/features/emotional/presentation/pages/check_in_quick_page.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckInQuickView', () {
    testWidgets('shows quick moods and expands additional mood groups', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('briefing'), findsNothing);
      expect(find.text('Calma'), findsOneWidget);
      expect(find.text('Ansiedade'), findsOneWidget);
      expect(find.text('Cansaço'), findsOneWidget);
      expect(find.text('Distração'), findsOneWidget);
      expect(find.text('Mais estados'), findsOneWidget);
      expect(find.text('Foco'), findsNothing);

      await tester.tap(find.text('Mais estados'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Voltar'), findsOneWidget);
      expect(find.text('Buscar estado'), findsOneWidget);
      expect(find.text('Emocionais'), findsOneWidget);
      expect(find.text('Mentais'), findsOneWidget);
      expect(find.text('Físicos'), findsOneWidget);
      expect(find.text('Comportamentais'), findsOneWidget);

      await tester.ensureVisible(find.text('Foco'));
      await tester.tap(find.text('Foco'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Estado selecionado: Foco'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Foco'), findsOneWidget);
    });

    testWidgets('supports other mood with optional free text', (tester) async {
      final repository = _FakeCheckInRepository();

      await tester.pumpWidget(_testApp(checkInRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mais estados'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Outro estado'));
      await tester.tap(find.text('Outro estado'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Estado selecionado: Outro estado'), findsOneWidget);
      expect(find.text('Descreva com suas palavras'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descreva com suas palavras'),
        'saudade tranquila',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.createdMood, 'saudade tranquila');
    });

    testWidgets('creates check-in and calls completion callback', (
      tester,
    ) async {
      var completed = false;
      final repository = _FakeCheckInRepository();

      await tester.pumpWidget(
        _testApp(
          checkInRepository: repository,
          onCompleted: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'preciso organizar o dia',
      );
      await tester.tap(find.text('Fazer check-in'));
      await tester.pumpAndSettle();

      expect(repository.createdMood, 'calma');
      expect(repository.createdReflection, 'preciso organizar o dia');
      expect(repository.createdEnergy, 7);
      expect(completed, isTrue);
    });

    testWidgets(
      'unlocks extra free check-in with rewarded ad and retries submit',
      (tester) async {
        final repository = _FakeCheckInRepository(
          blockFirstCreateWith402: true,
        );
        final rewarded = _FakeRewardedAdService(result: true);

        await tester.pumpWidget(
          _testApp(
            checkInRepository: repository,
            rewardedAdService: rewarded,
            subscriptionRepository: _FakeSubscriptionRepository(
              accessAllowed: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'preciso registrar outro momento',
        );
        await tester.tap(find.text('Fazer check-in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Desbloquear novo check-in hoje'), findsOneWidget);

        await tester.tap(find.text('Assistir anúncio'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(rewarded.rewardType, 'DEEP_EMOTIONAL_READING');
        expect(repository.createCalls, 2);
        expect(repository.createdReflection, 'preciso registrar outro momento');
      },
    );
  });
}

Widget _testApp({
  CheckInRepository? checkInRepository,
  RewardedAdService? rewardedAdService,
  SubscriptionRepository? subscriptionRepository,
  VoidCallback? onCompleted,
}) {
  return ProviderScope(
    overrides: [
      checkInRepositoryProvider.overrideWithValue(
        checkInRepository ?? _FakeCheckInRepository(),
      ),
      if (rewardedAdService != null)
        rewardedAdServiceProvider.overrideWithValue(rewardedAdService),
      if (subscriptionRepository != null)
        subscriptionRepositoryProvider.overrideWithValue(
          subscriptionRepository,
        ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CheckInQuickView(onCompleted: onCompleted),
        ),
      ),
    ),
  );
}

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({
    List<CheckIn>? items,
    this.blockFirstCreateWith402 = false,
  }) : items = items ?? _checkIns();

  final List<CheckIn> items;
  final bool blockFirstCreateWith402;
  int createCalls = 0;
  String? createdMood;
  String? createdReflection;
  int? createdEnergy;

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
    return PaginatedResponse(
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
    createCalls++;
    if (blockFirstCreateWith402 && createCalls == 1) {
      final requestOptions = RequestOptions(path: '/v1/check-ins');
      throw DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 402,
          data: const {
            'message':
                'Você já fez o check-in gratuito de hoje. Assista a um anúncio, assine Premium ou volte amanhã.',
          },
        ),
      );
    }
    createdMood = mood;
    createdReflection = reflection;
    createdEnergy = energyLevel;

    return CheckIn(
      id: 99,
      userId: 'user-123',
      mood: mood,
      reflection: reflection ?? '',
      energyLevel: energyLevel,
      recommendedPractice: 'Respire por dois minutos.',
      aiInsight: _insight(),
      createdAt: DateTime.now(),
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
        recommendedPractice: 'Respire por dois minutos.',
        aiInsight: _insight(),
        createdAt: DateTime.now(),
      ),
    );
  }
}

class _FakeRewardedAdService implements RewardedAdService {
  _FakeRewardedAdService({required this.result});

  final bool result;
  String? rewardType;

  @override
  Future<bool> showRewardedAd({
    required String rewardType,
    String? contextId,
  }) async {
    this.rewardType = rewardType;
    return result;
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({required this.accessAllowed});

  final bool accessAllowed;

  @override
  Future<CurrentSubscription?> cancel() async => null;

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) {
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
  Future<CurrentSubscription?> current() async => null;

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) async {
    return MonetizationAccessStatus(
      resource: resource,
      contextId: contextId,
      allowed: accessAllowed,
      premium: false,
      rewardedAdAvailable: !accessAllowed,
      upgradeRecommended: !accessAllowed,
      entitlementExpiresAt: accessAllowed
          ? DateTime.now().add(const Duration(hours: 2))
          : null,
    );
  }

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) {
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
}

List<CheckIn> _checkIns() {
  return [
    CheckIn(
      id: 1,
      userId: 'user-123',
      mood: 'ansioso',
      reflection: 'manha intensa',
      energyLevel: 6,
      recommendedPractice: 'Respiracao curta',
      aiInsight: _insight(),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

CheckInAiInsight _insight() {
  return const CheckInAiInsight(
    insight: 'Um momento de ansiedade leve.',
    suggestedAction: 'Respire por alguns ciclos.',
    riskLevel: 'low',
    suggestedTrailId: null,
    suggestedTrailTitle: null,
    suggestedTrailReason: '',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: false,
  );
}
