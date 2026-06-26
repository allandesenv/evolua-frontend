import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/daily_ritual/data/models/daily_ritual_dto.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/entities/daily_ritual.dart';
import 'package:evolua_frontend/features/daily_ritual/domain/repositories/daily_ritual_repository.dart';

class DailyRitualRepositoryImpl implements DailyRitualRepository {
  const DailyRitualRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<DailyRitual?> today({
    required String type,
    required DateTime localDate,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/daily-rituals/today',
      queryParameters: {'type': type, 'localDate': _formatDate(localDate)},
    );
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw['data'] == null) {
      return null;
    }
    return DailyRitualDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<List<DailyRitual>> list({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/daily-rituals',
      queryParameters: {'start': _formatDate(start), 'end': _formatDate(end)},
    );
    return ApiPayloadParser.dataList(
      response.data,
    ).map((item) => DailyRitualDto.fromJson(item).toEntity()).toList();
  }

  @override
  Future<DailyRitual> create(DailyRitualDraft draft) async {
    final response = await _dio.post<dynamic>(
      '/v1/daily-rituals',
      data: draft.toJson(),
    );
    return DailyRitualDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  String _formatDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}
