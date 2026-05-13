import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service.dart';
import 'package:evolua_frontend/features/ads/application/rewarded_ad_service_base.dart';
import 'package:evolua_frontend/features/content/application/journey_chat_controller.dart';
import 'package:evolua_frontend/features/content/application/trail_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_message.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_reply.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/repositories/journey_chat_repository.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/mentor_evolua_module_view.dart';
import 'package:evolua_frontend/features/subscription/application/mentor_premium_pass_reward_service.dart';
import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/features/subscription/domain/entities/subscription_record.dart';
import 'package:evolua_frontend/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Mentor sends only previous messages as conversation history', (
    tester,
  ) async {
    final repository = _FakeJourneyChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyChatRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MentorEvoluaChatCard(trail: null),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Qual a melhor meditacao pra mim agora?',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(repository.lastMessage, 'Qual a melhor meditacao pra mim agora?');
    expect(repository.lastConversationHistory, hasLength(1));
    expect(repository.lastConversationHistory.single.role, 'assistant');
    expect(
      repository.lastConversationHistory.where(
        (item) => item.content == repository.lastMessage,
      ),
      isEmpty,
    );
  });

  testWidgets('Mentor shows rewarded ad and premium actions when quota ends', (
    tester,
  ) async {
    final repository = _FakeJourneyChatRepository(
      reply: const JourneyChatReply(
        reply: 'Posso te oferecer um passo seguro sem usar IA externa agora.',
        riskLevel: 'low',
        suggestedNextStep: 'Respire por 2 minutos.',
        fallbackUsed: true,
        quotaLimited: true,
        rewardedAdAvailable: true,
        upgradeRecommended: true,
        limitMessage: 'Voce chegou ao limite de IA do plano gratuito hoje.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyChatRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MentorEvoluaChatCard(trail: null, onOpenPremium: () {}),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Quero conversar agora');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Limite de IA atingido'), findsOneWidget);
    expect(
      find.text('Voce chegou ao limite de IA do plano gratuito hoje.'),
      findsOneWidget,
    );
    expect(find.text('Assistir anuncio para +1 analise'), findsOneWidget);
    expect(find.text('Assinar Premium'), findsOneWidget);
  });

  testWidgets('Mentor unlocks daily premium pass through rewarded ad', (
    tester,
  ) async {
    final subscriptionRepository = _FakeSubscriptionRepository(
      mentorPassActiveFromCall: 4,
    );
    final rewardedService = _FakeRewardedAdService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyChatRepositoryProvider.overrideWithValue(
            _FakeJourneyChatRepository(),
          ),
          trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            subscriptionRepository,
          ),
          rewardedAdServiceProvider.overrideWithValue(rewardedService),
          mentorPremiumPassPollingConfigProvider.overrideWithValue(
            const MentorPremiumPassPollingConfig(
              timeout: Duration(milliseconds: 80),
              interval: Duration(milliseconds: 1),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MentorEvoluaModuleView(
                onOpenTrails: () {},
                onOpenPremium: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conteudos exclusivos de mentoria'), findsOneWidget);
    expect(
      find.text('Assistir anuncio para liberar mentoria por hoje'),
      findsOneWidget,
    );

    await tester.tap(
      find.text('Assistir anuncio para liberar mentoria por hoje'),
    );
    await tester.pumpAndSettle();

    expect(rewardedService.lastRewardType, 'MENTOR_PREMIUM_PASS');
    expect(subscriptionRepository.currentCallCount, greaterThanOrEqualTo(4));
    expect(find.text('Passe de mentoria ativo'), findsOneWidget);
  });

  testWidgets('Mentor keeps pass locked when SSV confirmation does not arrive', (
    tester,
  ) async {
    final subscriptionRepository = _FakeSubscriptionRepository();
    final rewardedService = _FakeRewardedAdService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyChatRepositoryProvider.overrideWithValue(
            _FakeJourneyChatRepository(),
          ),
          trailRepositoryProvider.overrideWithValue(_FakeTrailRepository()),
          subscriptionRepositoryProvider.overrideWithValue(
            subscriptionRepository,
          ),
          rewardedAdServiceProvider.overrideWithValue(rewardedService),
          mentorPremiumPassPollingConfigProvider.overrideWithValue(
            const MentorPremiumPassPollingConfig(
              timeout: Duration(milliseconds: 20),
              interval: Duration(milliseconds: 5),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MentorEvoluaModuleView(
                onOpenTrails: () {},
                onOpenPremium: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Assistir anuncio para liberar mentoria por hoje'),
    );
    await tester.pumpAndSettle();

    expect(rewardedService.lastRewardType, 'MENTOR_PREMIUM_PASS');
    expect(find.text('Passe de mentoria ativo'), findsNothing);
    expect(
      find.text(
        'O anuncio foi concluido, mas ainda nao recebemos a confirmacao. Toque em Atualizar em instantes.',
      ),
      findsWidgets,
    );
  });
}

class _FakeJourneyChatRepository implements JourneyChatRepository {
  _FakeJourneyChatRepository({
    this.reply = const JourneyChatReply(
      reply: 'Vamos fazer uma pratica curta.',
      riskLevel: 'low',
      suggestedNextStep: 'Respire por 3 minutos.',
      fallbackUsed: true,
    ),
  });

  final JourneyChatReply reply;
  String? lastMessage;
  List<JourneyChatMessage> lastConversationHistory = const [];

  @override
  Future<JourneyChatReply> send({
    required String message,
    required List<JourneyChatMessage> conversationHistory,
    int? trailId,
  }) async {
    lastMessage = message;
    lastConversationHistory = List.of(conversationHistory);
    return reply;
  }
}

class _FakeRewardedAdService implements RewardedAdService {
  String? lastRewardType;

  @override
  Future<bool> showRewardedAd({required String rewardType}) async {
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
  Future<AdRewardSession> createRewardSession({required String rewardType}) {
    throw UnimplementedError();
  }

  @override
  Future<CurrentSubscription?> cancel() async => current();

  @override
  Future<CheckoutSession> checkoutStatus(String checkoutId) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutSession> startCheckout({
    required String planCode,
    required String frontendBaseUrl,
  }) {
    throw UnimplementedError();
  }
}

class _FakeTrailRepository implements TrailRepository {
  @override
  Future<Trail?> currentJourney() async => null;

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
    return PaginatedResponse(
      items: const [],
      page: page,
      size: size,
      totalItems: 0,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: const {},
    );
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
  Future<TrailJourney> journey(int trailId) {
    throw UnimplementedError();
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
