import 'package:evolua_frontend/features/content/application/journey_chat_controller.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_message.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_reply.dart';
import 'package:evolua_frontend/features/content/domain/repositories/journey_chat_repository.dart';
import 'package:evolua_frontend/features/content/presentation/widgets/mentor_evolua_module_view.dart';
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
              child: MentorEvoluaChatCard(
                trail: null,
                onOpenPremium: () {},
              ),
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
