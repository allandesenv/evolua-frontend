import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';

abstract class NotificationRepository {
  Future<List<NotificationJob>> list();

  Future<NotificationJob> create({
    required String channel,
    required String message,
  });
}
