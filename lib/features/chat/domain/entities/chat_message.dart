class ChatMessage {
  const ChatMessage({
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
}
