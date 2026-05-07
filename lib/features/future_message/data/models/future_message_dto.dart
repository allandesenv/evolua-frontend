import 'package:evolua_frontend/features/future_message/domain/entities/future_message.dart';

class FutureMessageDto {
  const FutureMessageDto({
    required this.id,
    required this.title,
    required this.body,
    required this.bodyPreview,
    required this.triggerType,
    required this.triggerConfig,
    required this.triggerLabel,
    required this.status,
    required this.createdContext,
    required this.deliveredContext,
    required this.createdAt,
    required this.scheduledFor,
    required this.deliveredAt,
    required this.readAt,
    required this.reaction,
  });

  final int id;
  final String? title;
  final String body;
  final String bodyPreview;
  final String triggerType;
  final Map<String, dynamic> triggerConfig;
  final String triggerLabel;
  final String status;
  final Map<String, dynamic> createdContext;
  final Map<String, dynamic> deliveredContext;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? reaction;

  factory FutureMessageDto.fromJson(Map<String, dynamic> json) {
    return FutureMessageDto(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString(),
      body: json['body']?.toString() ?? json['bodyPreview']?.toString() ?? '',
      bodyPreview: json['bodyPreview']?.toString() ?? '',
      triggerType: json['triggerType']?.toString() ?? '',
      triggerConfig: _map(json['triggerConfig']),
      triggerLabel: json['triggerLabel']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SCHEDULED',
      createdContext: _map(json['createdContext']),
      deliveredContext: _map(json['deliveredContext']),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      scheduledFor: _date(json['scheduledFor']),
      deliveredAt: _date(json['deliveredAt']),
      readAt: _date(json['readAt']),
      reaction: json['reaction']?.toString(),
    );
  }

  FutureMessage toEntity() {
    return FutureMessage(
      id: id,
      title: title,
      body: body,
      bodyPreview: bodyPreview,
      triggerType: triggerType,
      triggerConfig: triggerConfig,
      triggerLabel: triggerLabel,
      status: status,
      createdContext: createdContext,
      deliveredContext: deliveredContext,
      createdAt: createdAt,
      scheduledFor: scheduledFor,
      deliveredAt: deliveredAt,
      readAt: readAt,
      reaction: reaction,
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static DateTime? _date(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }
    return DateTime.parse(value.toString());
  }
}
