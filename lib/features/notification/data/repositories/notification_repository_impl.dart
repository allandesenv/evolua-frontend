import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/notification/data/models/notification_job_dto.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<NotificationJob>> list({bool unreadOnly = false}) async {
    final response = await _dio.get<dynamic>(
      '/v1/notifications',
      queryParameters: {'size': 20, if (unreadOnly) 'unreadOnly': true},
    );

    return ApiPayloadParser.dataList(
      response.data,
    ).map(NotificationJobDto.fromJson).map((item) => item.toEntity()).toList();
  }

  @override
  Future<int> unreadCount() async {
    final response = await _dio.get<dynamic>('/v1/notifications/unread-count');
    final data = ApiPayloadParser.dataMap(response.data);
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<NotificationJob> markAsRead(String id) async {
    final response = await _dio.post<dynamic>('/v1/notifications/$id/read');
    return NotificationJobDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<int> markAllAsRead() async {
    final response = await _dio.post<dynamic>('/v1/notifications/read-all');
    final data = ApiPayloadParser.dataMap(response.data);
    return (data['updatedCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<NotificationJob> createAdmin({
    required String targetUserId,
    required String type,
    required String title,
    required String message,
    String? actionTarget,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/admin/notifications',
      data: {
        'targetUserId': targetUserId,
        'type': type,
        'title': title,
        'message': message,
        'actionTarget': actionTarget,
      },
    );

    return NotificationJobDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }
}
