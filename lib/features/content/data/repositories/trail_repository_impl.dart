import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/network/pagination_query.dart';
import 'package:evolua_frontend/features/content/data/models/trail_journey_dto.dart';
import 'package:evolua_frontend/features/content/data/models/trail_dto.dart';
import 'package:evolua_frontend/features/content/data/models/trail_step_response_dto.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_journey.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_media_link.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step.dart';
import 'package:evolua_frontend/features/content/domain/entities/trail_step_response.dart';
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
    required List<TrailStep> steps,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/trails',
      data: _trailPayload(
        title: title,
        summary: summary,
        content: content,
        category: category,
        premium: premium,
        mediaLinks: mediaLinks,
        steps: steps,
      ),
    );

    return TrailDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<Trail> update({
    required int id,
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) async {
    final response = await _dio.put<dynamic>(
      '/v1/trails/$id',
      data: _trailPayload(
        title: title,
        summary: summary,
        content: content,
        category: category,
        premium: premium,
        mediaLinks: mediaLinks,
        steps: steps,
      ),
    );

    return TrailDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<void> delete(int id) async {
    await _dio.delete<dynamic>('/v1/trails/$id');
  }

  Map<String, Object?> _trailPayload({
    required String title,
    required String summary,
    required String content,
    required String category,
    required bool premium,
    required List<TrailMediaLink> mediaLinks,
    required List<TrailStep> steps,
  }) {
    return {
      'title': title,
      'summary': summary,
      'content': content,
      'category': category,
      'premium': premium,
      'mediaLinks': mediaLinks
          .map(
            (link) => {'label': link.label, 'url': link.url, 'type': link.type},
          )
          .toList(),
      'steps': steps
          .map(
            (step) => {
              'title': step.title,
              'type': step.type,
              'summary': step.summary,
              'durationMinutes': step.durationMinutes,
              'content': step.content,
              'videoProvider': step.video?.provider,
              'videoId': step.video?.videoId,
              'videoUrl': step.video?.url,
              'thumbnailUrl': step.video?.thumbnailUrl,
              'durationSeconds': step.video?.durationSeconds,
              'mediaLinks': step.mediaLinks
                  .map(
                    (link) => {
                      'label': link.label,
                      'url': link.url,
                      'type': link.type,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
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
    return TrailJourneyDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<TrailJourney> startJourney(int trailId) async {
    final response = await _dio.post<dynamic>(
      '/v1/trails/$trailId/journey/start',
    );
    return TrailJourneyDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<TrailJourney> completeStep(int trailId, int stepIndex) async {
    final response = await _dio.post<dynamic>(
      '/v1/trails/$trailId/journey/steps/$stepIndex/complete',
    );
    return TrailJourneyDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<TrailJourney> updateVideoProgress({
    required int trailId,
    required int stepIndex,
    required int watchedSeconds,
    required int durationSeconds,
  }) async {
    final response = await _dio.put<dynamic>(
      '/v1/trails/$trailId/journey/steps/$stepIndex/video-progress',
      data: {
        'watchedSeconds': watchedSeconds,
        'durationSeconds': durationSeconds,
      },
    );
    return TrailJourneyDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<TrailStepResponse?> stepResponse({
    required int trailId,
    required int stepIndex,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/trails/$trailId/journey/steps/$stepIndex/response',
    );
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw['data'] == null) {
      return null;
    }
    return TrailStepResponseDto.fromJson(
      ApiPayloadParser.dataMap(raw),
    ).toEntity();
  }

  @override
  Future<TrailStepResponse> saveStepResponse({
    required int trailId,
    required int stepIndex,
    required String responseText,
  }) async {
    final response = await _dio.put<dynamic>(
      '/v1/trails/$trailId/journey/steps/$stepIndex/response',
      data: {'responseText': responseText},
    );
    return TrailStepResponseDto.fromJson(
      ApiPayloadParser.dataMap(response.data),
    ).toEntity();
  }

  @override
  Future<List<TrailStepResponse>> listStepResponses({int limit = 20}) async {
    final response = await _dio.get<dynamic>(
      '/v1/trails/step-responses',
      queryParameters: {'limit': limit},
    );
    return ApiPayloadParser.dataList(
      response.data,
    ).map((item) => TrailStepResponseDto.fromJson(item).toEntity()).toList();
  }
}
