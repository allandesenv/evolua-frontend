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
          home: Scaffold(body: MentorEvoluaChatCard(trail: null)),
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
}

class _FakeJourneyChatRepository implements JourneyChatRepository {
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
    return const JourneyChatReply(
      reply: 'Vamos fazer uma pratica curta.',
      riskLevel: 'low',
      suggestedNextStep: 'Respire por 3 minutos.',
      fallbackUsed: true,
    );
  }
}
