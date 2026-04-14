class NotificationJob {
  const NotificationJob({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.actionTarget,
    required this.source,
    required this.createdBy,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? actionTarget;
  final String source;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  NotificationJob copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    String? actionTarget,
    String? source,
    String? createdBy,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationJob(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      actionTarget: actionTarget ?? this.actionTarget,
      source: source ?? this.source,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
