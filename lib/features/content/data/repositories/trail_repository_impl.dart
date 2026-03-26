import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/features/content/data/models/trail_dto.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';

class TrailRepositoryImpl implements TrailRepository {
  const TrailRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Trail>> list() async {
    final response = await _dio.get<dynamic>('/v1/trails');

    return ApiPayloadParser.dataList(response.data)
        .map(TrailDto.fromJson)
        .map((item) => item.toEntity())
        .toList();
  }

  @override
  Future<Trail> create({
    required String title,
    required String description,
    required String category,
    required bool premium,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/trails',
      data: {
        'title': title,
        'description': description,
        'category': category,
        'premium': premium,
      },
    );

    return TrailDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
