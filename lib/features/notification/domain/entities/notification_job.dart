class NotificationJob {
  const NotificationJob({
    required this.id,
    required this.userId,
    required this.channel,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String channel;
  final String message;
  final DateTime createdAt;
}
