import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/notification/data/models/notification_job_dto.dart';
import 'package:evolua_frontend/features/notification/domain/entities/notification_job.dart';
import 'package:evolua_frontend/features/notification/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<NotificationJob>> list() async {
    final response = await _dio.get<dynamic>('/v1/notifications');

    return ApiPayloadParser.dataList(response.data)
        .map(NotificationJobDto.fromJson)
        .map((item) => item.toEntity())
        .toList();
  }

  @override
  Future<NotificationJob> create({
    required String channel,
    required String message,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/notifications',
      data: {
        'channel': channel,
        'message': message,
      },
    );

    return NotificationJobDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
