import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/content/data/models/trail_dto.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/repositories/trail_repository.dart';

class TrailRepositoryImpl implements TrailRepository {
  const TrailRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaginatedResponse<Trail>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? category,
    bool? premium,
  }) async {
    final query = PaginationQuery(
      page: page,
      size: size,
      search: search,
      sortBy: sortBy,
      sortDir: sortDir,
    );

    final response = await _dio.get<dynamic>(
      '/v1/trails',
      queryParameters: query.toQueryParameters({
        'category': category,
        'premium': premium,
      }),
    );

    return ApiPayloadParser.paginatedData(
      response.data,
      (item) => TrailDto.fromJson(item).toEntity(),
    );
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
