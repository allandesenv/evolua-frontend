import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/presentation/widgets/check_in_ai_insight_card.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows rewarded ad and premium actions when check-in quota ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        premium: false,
        child: CheckInAiInsightCard(
          insight: const CheckInAiInsight(
            insight: 'Salvamos seu check-in com uma orientacao segura.',
            suggestedAction: 'Respire por dois minutos.',
            riskLevel: 'low',
            suggestedTrailId: null,
            suggestedTrailTitle: null,
            suggestedTrailReason: '',
            suggestedSpace: null,
            journeyPlan: null,
            generatedTrailDraft: null,
            fallbackUsed: true,
            quotaLimited: true,
            rewardedAdAvailable: true,
            upgradeRecommended: true,
            limitMessage:
                'Sua jornada já está salva. O limite gratuito de IA acabou por hoje. Você pode voltar amanhã, assistir a um anúncio para liberar +1 análise ou assinar Premium.',
          ),
          onWatchRewardedAd: () {},
          onOpenPremium: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Limite de IA atingido'), findsOneWidget);
    expect(
      find.text(
        'Sua jornada já está salva. O limite gratuito de IA acabou por hoje. Você pode voltar amanhã, assistir a um anúncio para liberar +1 análise ou assinar Premium.',
      ),
      findsOneWidget,
    );
    expect(find.text('Assistir anúncio'), findsOneWidget);
    expect(find.text('Aprofundar com Premium'), findsOneWidget);
  });

  testWidgets('shows personalization signals and reading actions', (
    tester,
  ) async {
    final selectedStyles = <String>[];
    var saved = false;
    var ritual = false;

    await tester.pumpWidget(
      _testApp(
        premium: true,
        child: CheckInAiInsightCard(
          insight: CheckInAiInsight(
            insight:
                'Ana, seus ultimos registros mostram melhora gradual hoje.',
            suggestedAction: 'Continue com um passo simples.',
            riskLevel: 'low',
            suggestedTrailId: null,
            suggestedTrailTitle: null,
            suggestedTrailReason: '',
            suggestedSpace: null,
            journeyPlan: null,
            generatedTrailDraft: null,
            fallbackUsed: false,
            contextSignals: const ['ultimos check-ins', 'trilha ativa'],
            usedContextSummary:
                'Com base nos seus ultimos check-ins e na trilha ativa.',
            nextStep: const CheckInAiNextStep(
              type: 'ritual',
              label: 'Fazer uma pausa guiada de 2 minutos.',
            ),
          ),
          onRegenerate: selectedStyles.add,
          onSaveReading: () => saved = true,
          onCreateRitual: () => ritual = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personalizada'), findsOneWidget);
    expect(find.text('ultimos check-ins'), findsOneWidget);
    expect(find.text('trilha ativa'), findsOneWidget);
    expect(find.text('Mais curta'), findsOneWidget);
    expect(find.text('Salvar leitura'), findsOneWidget);
    expect(find.text('Transformar em ritual'), findsOneWidget);

    await tester.tap(find.text('Mais pratica'));
    await tester.tap(find.text('Salvar leitura'));
    await tester.tap(find.text('Transformar em ritual'));

    expect(selectedStyles, ['practical']);
    expect(saved, isTrue);
    expect(ritual, isTrue);
  });

  testWidgets('blocks refinement actions for free users with premium prompt', (
    tester,
  ) async {
    final selectedStyles = <String>[];
    var premiumOpened = false;

    await tester.pumpWidget(
      _testApp(
        premium: false,
        child: CheckInAiInsightCard(
          insight: _personalizedInsight(),
          onRegenerate: selectedStyles.add,
          onOpenPremium: () => premiumOpened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mais profunda'));
    await tester.pumpAndSettle();

    expect(selectedStyles, isEmpty);
    expect(find.text('Recurso Premium'), findsOneWidget);
    expect(find.text('Conhecer Premium'), findsOneWidget);

    await tester.tap(find.text('Conhecer Premium'));
    await tester.pumpAndSettle();

    expect(premiumOpened, isTrue);
  });

  testWidgets('premium users can use all refinement actions', (tester) async {
    final selectedStyles = <String>[];

    await tester.pumpWidget(
      _testApp(
        premium: true,
        child: CheckInAiInsightCard(
          insight: _personalizedInsight(),
          onRegenerate: selectedStyles.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mais curta'));
    await tester.tap(find.text('Mais profunda'));
    await tester.tap(find.text('Mais pratica'));
    await tester.tap(find.text('Gerar outra versao'));

    expect(selectedStyles, ['quick', 'deep', 'practical', 'balanced']);
  });
}

Widget _testApp({required Widget child, required bool premium}) {
  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(
        _FakeSubscriptionRepository(premium: premium),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

CheckInAiInsight _personalizedInsight() {
  return const CheckInAiInsight(
    insight: 'Ana, seus ultimos registros mostram melhora gradual hoje.',
    suggestedAction: 'Continue com um passo simples.',
    riskLevel: 'low',
    suggestedTrailId: null,
    suggestedTrailTitle: null,
    suggestedTrailReason: '',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: false,
    contextSignals: ['ultimos check-ins', 'trilha ativa'],
    usedContextSummary:
        'Com base nos seus ultimos check-ins e na trilha ativa.',
    nextStep: CheckInAiNextStep(
      type: 'ritual',
      label: 'Fazer uma pausa guiada de 2 minutos.',
    ),
  );
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  const _FakeSubscriptionRepository({required this.premium});

  final bool premium;

  @override
  Future<CurrentSubscription?> current() async => CurrentSubscription(
    planCode: premium ? 'premium' : 'free',
    status: 'ACTIVE',
    billingCycle: 'MONTHLY',
    premium: premium,
    adsEnabled: !premium,
    aiQuotaRemainingToday: premium ? 99 : 0,
    mentorPremiumPassActive: false,
    mentorRewardedAdAvailable: false,
  );

  @override
  Future<List<PlanView>> listPlans() async => const [];

  @override
  Future<CurrentSubscription?> cancel() async => current();

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
  Future<AdRewardSession> grantClientOpenedReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardSession> grantTestReward(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<MonetizationAccessStatus> monetizationAccess({
    required String resource,
    String? contextId,
  }) {
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
  Future<CheckoutSession> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required String packageName,
    required String planCode,
  }) {
    throw UnimplementedError();
  }
}
