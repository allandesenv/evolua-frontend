import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/social/data/models/social_post_dto.dart';
import 'package:evolua_frontend/features/social/domain/entities/social_post.dart';
import 'package:evolua_frontend/features/social/domain/repositories/social_post_repository.dart';

class SocialPostRepositoryImpl implements SocialPostRepository {
  const SocialPostRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaginatedResponse<SocialPost>> list({
    required int page,
    required int size,
    String? search,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    String? community,
    String? visibility,
  }) async {
    final query = PaginationQuery(
      page: page,
      size: size,
      search: search,
      sortBy: sortBy,
      sortDir: sortDir,
    );

    final response = await _dio.get<dynamic>(
      '/v1/posts',
      queryParameters: query.toQueryParameters({
        'community': community,
        'visibility': visibility,
      }),
    );

    return ApiPayloadParser.paginatedData(
      response.data,
      (item) => SocialPostDto.fromJson(item).toEntity(),
    );
  }

  @override
  Future<SocialPost> create({
    required String content,
    required String community,
    required String visibility,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/posts',
      data: {
        'content': content,
        'community': community,
        'visibility': visibility,
      },
    );

    return SocialPostDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
