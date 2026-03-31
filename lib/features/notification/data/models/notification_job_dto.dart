import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';

class NotificationJobDto {
  const NotificationJobDto({
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

  factory NotificationJobDto.fromJson(Map<String, dynamic> json) {
    return NotificationJobDto(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      channel: json['channel'].toString(),
      message: json['message'].toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  NotificationJob toEntity() {
    return NotificationJob(
      id: id,
      userId: userId,
      channel: channel,
      message: message,
      createdAt: createdAt,
    );
  }
}
