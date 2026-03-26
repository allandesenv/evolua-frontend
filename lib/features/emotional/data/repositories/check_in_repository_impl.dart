import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/emotional/data/models/check_in_dto.dart';
import 'package:evolua_frontend/features/emotional/domain/entities/check_in.dart';
import 'package:evolua_frontend/features/emotional/domain/repositories/check_in_repository.dart';

class CheckInRepositoryImpl implements CheckInRepository {
  const CheckInRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<CheckIn>> list() async {
    final response = await _dio.get<dynamic>('/v1/check-ins');

    return ApiPayloadParser.dataList(response.data)
        .map(CheckInDto.fromJson)
        .map((item) => item.toEntity())
        .toList();
  }

  @override
  Future<CheckIn> create({
    required String mood,
    required String reflection,
    required int energyLevel,
    required String recommendedPractice,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/check-ins',
      data: {
        'mood': mood,
        'reflection': reflection,
        'energyLevel': energyLevel,
        'recommendedPractice': recommendedPractice,
      },
    );

    return CheckInDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
