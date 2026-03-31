import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';

class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.userId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String recipientId;
  final String content;
  final DateTime createdAt;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      recipientId: json['recipientId'].toString(),
      content: json['content'].toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  ChatMessage toEntity() {
    return ChatMessage(
      id: id,
      userId: userId,
      recipientId: recipientId,
      content: content,
      createdAt: createdAt,
    );
  }
}
