import 'package:evolua_frontend/features/content/domain/entities/journey_chat_message.dart';
import 'package:evolua_frontend/features/content/domain/entities/journey_chat_reply.dart';

abstract class JourneyChatRepository {
  Future<JourneyChatReply> send({
    required String message,
    required List<JourneyChatMessage> conversationHistory,
    int? trailId,
  });
}
