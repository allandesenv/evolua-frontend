import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/social/data/models/community_dto.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/features/social/domain/repositories/community_repository.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  const CommunityRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaginatedResponse<Community>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? visibility,
    String? category,
    bool? joined,
  }) async {
    final query = PaginationQuery(
      page: page,
      size: size,
      search: search,
      sortBy: sortBy,
      sortDir: sortDir,
    );

    final response = await _dio.get<dynamic>(
      '/v1/communities',
      queryParameters: query.toQueryParameters({
        'visibility': visibility,
        'category': category,
        'joined': joined,
      }),
    );

    return ApiPayloadParser.paginatedData(
      response.data,
      (item) => CommunityDto.fromJson(item).toEntity(),
    );
  }

  @override
  Future<Community> create({
    required String name,
    required String slug,
    required String description,
    required String visibility,
    required String category,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/communities',
      data: {
        'name': name,
        'slug': slug,
        'description': description,
        'visibility': visibility,
        'category': category,
      },
    );

    return CommunityDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }

  @override
  Future<Community> join(String id) async {
    final response = await _dio.post<dynamic>('/v1/communities/$id/join');
    return CommunityDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }

  @override
  Future<Community> leave(String id) async {
    final response = await _dio.post<dynamic>('/v1/communities/$id/leave');
    return CommunityDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
