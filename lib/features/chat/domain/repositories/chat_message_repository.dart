import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';

abstract class ChatMessageRepository {
  Future<PaginatedResponse<ChatMessage>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? recipientId,
  });

  Future<ChatMessage> create({
    required String recipientId,
    required String content,
  });
}
