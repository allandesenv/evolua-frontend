import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/content/data/models/trail_journey_dto.dart';
import 'package:evolua_frontend/features/content/data/models/trail_dto.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
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
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/trails',
      data: {
        'title': title,
        'summary': summary,
        'content': content,
        'category': category,
        'premium': premium,
        'mediaLinks': mediaLinks
            .map(
              (link) => {
                'label': link.label,
                'url': link.url,
                'type': link.type,
              },
            )
            .toList(),
      },
    );

    return TrailDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }

  @override
  Future<Trail?> currentJourney() async {
    final response = await _dio.get<dynamic>('/v1/trails/journey/current');
    final data = (response.data as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }
    return TrailDto.fromJson(data).toEntity();
  }

  @override
  Future<TrailJourney> journey(int trailId) async {
    final response = await _dio.get<dynamic>('/v1/trails/$trailId/journey');
    return TrailJourneyDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }

  @override
  Future<TrailJourney> startJourney(int trailId) async {
    final response = await _dio.post<dynamic>('/v1/trails/$trailId/journey/start');
    return TrailJourneyDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) async {
    final response = await _dio.post<dynamic>(
      '/v1/trails/$trailId/journey/steps/$stepIndex/complete',
    );
    return TrailJourneyDto.fromJson(ApiPayloadParser.dataMap(response.data)).toEntity();
  }
}
