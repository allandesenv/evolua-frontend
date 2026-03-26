import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';

abstract class ChatMessageRepository {
  Future<List<ChatMessage>> list();

  Future<ChatMessage> create({
    required String recipientId,
    required String content,
  });
}
