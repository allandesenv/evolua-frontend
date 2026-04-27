import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';

abstract class NotificationRepository {
  Future<List<NotificationJob>> list({bool unreadOnly = false});

  Future<int> unreadCount();

  Future<NotificationJob> markAsRead(String id);

  Future<int> markAllAsRead();

  Future<NotificationJob> createAdmin({
    required String targetUserId,
    required String type,
    required String title,
    required String message,
    String? actionTarget,
  });
}
