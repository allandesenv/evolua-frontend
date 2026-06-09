import 'package:evolua_frontend/features/emotional/domain/entities/check_in_ai_insight.dart';
import 'package:evolua_frontend/features/emotional/data/models/check_in_dto.dart';
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
    await tester.pump();

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
    var history = false;

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
          onOpenHistory: () => history = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Personalizada'), findsOneWidget);
    expect(find.text('ultimos check-ins'), findsOneWidget);
    expect(find.text('trilha ativa'), findsOneWidget);
    expect(find.text('Mais curta'), findsNothing);
    expect(find.text('Ajustar leitura'), findsOneWidget);
    expect(find.text('Transformar em cuidado'), findsOneWidget);
    expect(find.text('Salvar leitura'), findsOneWidget);
    expect(find.text('Criar ritual do dia'), findsOneWidget);
    expect(find.text('Ver histórico'), findsOneWidget);

    await tester.tap(find.text('Ajustar leitura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais pratica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar leitura'));
    await tester.tap(find.text('Ver histórico'));
    await tester.tap(find.text('Criar ritual do dia'));

    expect(selectedStyles, ['practical']);
    expect(saved, isTrue);
    expect(ritual, isTrue);
    expect(history, isTrue);
  });

  testWidgets('renders structured deep reading when available', (tester) async {
    await tester.pumpWidget(
      _testApp(
        premium: true,
        child: CheckInAiInsightCard(insight: _structuredInsight()),
      ),
    );
    await tester.pump();

    expect(find.text('Quando a mente tenta proteger'), findsOneWidget);
    expect(find.text('O que aparece na superfície'), findsOneWidget);
    expect(find.text('O que pode estar por trás'), findsOneWidget);
    expect(find.text('O estado interno identificado'), findsOneWidget);
    expect(find.text('Pergunta reveladora'), findsOneWidget);
    expect(find.text('Novo estado possível'), findsOneWidget);
    expect(find.text('Microação'), findsOneWidget);
  });

  testWidgets('shows contextual loading on selected reading action', (
    tester,
  ) async {
    var saveTapped = false;

    await tester.pumpWidget(
      _testApp(
        premium: true,
        child: CheckInAiInsightCard(
          insight: _personalizedInsight(),
          onRegenerate: (_) {},
          onSaveReading: () => saveTapped = true,
          onCreateRitual: () {},
          readingActionLoading: ReadingActionLoading.deep,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Gerando...'), findsOneWidget);
    expect(find.text('Ajustar leitura'), findsNothing);

    await tester.tap(find.text('Salvar leitura'));
    await tester.pump();

    expect(saveTapped, isFalse);
  });

  testWidgets('shows create ritual action even without ritual next step', (
    tester,
  ) async {
    var ritual = false;

    await tester.pumpWidget(
      _testApp(
        premium: true,
        child: CheckInAiInsightCard(
          insight: _structuredInsight(),
          onCreateRitual: () => ritual = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Criar ritual do dia'), findsOneWidget);

    await tester.ensureVisible(find.text('Criar ritual do dia'));
    await tester.tap(find.text('Criar ritual do dia'));
    await tester.pump();

    expect(ritual, isTrue);
  });

  testWidgets('parses structured deep reading fields from dto', (tester) async {
    final dto = CheckInDto.fromJson({
      'id': 1,
      'userId': 'user-1',
      'mood': 'ansiedade',
      'reflection': 'texto',
      'energyLevel': 4,
      'recommendedPractice': 'Respire.',
      'savedReading': false,
      'createdAt': DateTime(2026, 6, 7).toIso8601String(),
      'aiInsight': {
        'insight': 'Leitura base.',
        'suggestedAction': 'Respire.',
        'riskLevel': 'low',
        'fallbackUsed': false,
        'title': 'Quando a mente tenta proteger',
        'surface': 'Na superfície, aparece ansiedade.',
        'behind': 'Talvez exista busca por controle.',
        'identifiedState': 'controle',
        'revealingQuestion': 'O que você tenta evitar sentir?',
        'possibleNewState': 'Eu posso trocar controle por cuidado.',
        'microAction': 'Respire por dois minutos.',
      },
    });

    expect(dto.aiInsight?.title, 'Quando a mente tenta proteger');
    expect(dto.aiInsight?.surface, 'Na superfície, aparece ansiedade.');
    expect(dto.aiInsight?.microAction, 'Respire por dois minutos.');
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

    await tester.tap(find.text('Ajustar leitura'));
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

    await tester.tap(find.text('Ajustar leitura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais curta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustar leitura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais profunda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustar leitura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais pratica'));
    await tester.pumpAndSettle();
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
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
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

CheckInAiInsight _structuredInsight() {
  return const CheckInAiInsight(
    insight: 'Parece haver uma tentativa de sustentar tudo ao mesmo tempo.',
    suggestedAction: 'Respire por dois minutos.',
    riskLevel: 'low',
    suggestedTrailId: null,
    suggestedTrailTitle: null,
    suggestedTrailReason: '',
    suggestedSpace: null,
    journeyPlan: null,
    generatedTrailDraft: null,
    fallbackUsed: false,
    title: 'Quando a mente tenta proteger',
    surface: 'Na superfície, aparece ansiedade com energia 4/10.',
    behind: 'Talvez exista uma busca por controle diante do incerto.',
    identifiedState: 'controle',
    revealingQuestion: 'O que você tenta evitar sentir quando controla tudo?',
    possibleNewState: 'Eu posso trocar controle por cuidado.',
    microAction: 'Respire por dois minutos antes de decidir o próximo passo.',
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
