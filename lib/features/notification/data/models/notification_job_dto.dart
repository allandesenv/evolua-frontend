import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';

class NotificationJobDto {
  const NotificationJobDto({
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

  factory NotificationJobDto.fromJson(Map<String, dynamic> json) {
    return NotificationJobDto(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      type: json['type'].toString(),
      title: json['title'].toString(),
      message: json['message'].toString(),
      actionTarget: json['actionTarget']?.toString(),
      source: json['source']?.toString() ?? 'SYSTEM',
      createdBy: json['createdBy']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'].toString()),
    );
  }

  NotificationJob toEntity() {
    return NotificationJob(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      actionTarget: actionTarget,
      source: source,
      createdBy: createdBy,
      createdAt: createdAt,
      readAt: readAt,
    );
  }
}
